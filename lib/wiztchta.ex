defmodule Wiztchta do
  @moduledoc """
  Drop-in, pluggable CAPTCHA for Phoenix forms and LiveViews.

  Render a challenge inside any form with `Wiztchta.Components.wiztchta/1`
  and check the submission with `verify/2` (or `Wiztchta.Plug` in controllers).

  Wiztchta is stateless: each challenge travels to the browser as an
  encrypted, expiring token that only your server can read. A pluggable
  `Wiztchta.Store` rejects tokens that are submitted more than once.

  ## Configuration

      config :wiztchta,
        # Required: either a secret or an endpoint whose secret_key_base is used.
        endpoint: MyAppWeb.Endpoint,
        # secret_key_base: "...",

        # Optional (defaults shown):
        default_challenge: Wiztchta.Challenges.ProofOfWork,
        max_age: 300,
        store: Wiztchta.Store.ETS,
        param: "wiztchta",
        honeypot: true,
        honeypot_field: "website",
        min_time: 2

  Every option can also be passed per call to `new/1` and `verify/2`.
  """

  alias Wiztchta.{Challenge, Config, Honeypot, Token}

  @type error ::
          :missing
          | :honeypot
          | :invalid_token
          | :expired
          | :too_fast
          | :already_used
          | :wrong_answer

  @doc """
  Generates a new challenge.

  ## Options

    * `:type` - the `Wiztchta.Challenge` module to use. Defaults to the
      `:default_challenge` config.
    * `:max_age` - seconds until the challenge expires.
    * Any other option is forwarded to the challenge's `c:Wiztchta.Challenge.generate/1`
      (for example `difficulty: 18` for `Wiztchta.Challenges.ProofOfWork`).
  """
  @spec new(keyword) :: Challenge.t()
  def new(opts \\ []) do
    type = Keyword.get(opts, :type) || Config.get(:default_challenge, opts)
    max_age = Config.get(:max_age, opts)
    {public, secret} = type.generate(opts)

    payload = %{
      id: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false),
      type: type,
      secret: secret,
      issued_at: System.system_time(:millisecond),
      expires_at: System.system_time(:second) + max_age
    }

    %Challenge{type: type, public: public, token: Token.encrypt(payload, max_age, opts)}
  end

  @doc """
  Verifies a submitted challenge.

  Accepts the full form params (looking under the `:param` key, `"wiztchta"`
  by default) or the inner `%{"token" => ..., "response" => ...}` map.

  Checks run cheapest first: the `Wiztchta.Honeypot` field, then the token
  (decrypt and expiry), then the minimum fill time, then single use, then
  the challenge answer. A token is consumed on its first verification attempt
  that reaches the store, whether the answer is right or wrong, so render a
  fresh challenge after every submit.

  ## Minimum fill time

  Submissions that arrive less than `:min_time` seconds (default `2`) after
  the challenge was created return `{:error, :too_fast}`: no person fills a
  form that quickly. The start time lives inside the encrypted token, so it
  can't be forged, and a too-fast attempt doesn't consume the token. Set
  `min_time: 0` to disable it, e.g. for login forms filled by password
  managers, and in your test environment.

      case Wiztchta.verify(params) do
        :ok -> ...
        {:error, reason} -> ...
      end
  """
  @spec verify(map, keyword) :: :ok | {:error, error}
  def verify(params, opts \\ []) do
    with {:ok, fields} <- fields(params, Config.get(:param, opts)),
         :ok <- Honeypot.check(fields, opts),
         {:ok, token, response} <- token_and_response(fields),
         {:ok, payload} <- Token.decrypt(token, opts),
         :ok <- check_min_time(payload, opts),
         :ok <- consume(payload, opts) do
      if payload.type.valid?(payload.secret, response, opts),
        do: :ok,
        else: {:error, :wrong_answer}
    end
  end

  @doc "Returns `true` if `verify/2` succeeds."
  @spec valid?(map, keyword) :: boolean
  def valid?(params, opts \\ []), do: verify(params, opts) == :ok

  @doc "A human-readable message for a `verify/2` error."
  @spec error_message(error) :: String.t()
  def error_message(:missing), do: "Please complete the verification."
  def error_message(:expired), do: "The verification expired. Please try again."
  def error_message(:too_fast), do: "That was quick! Please wait a moment and try again."
  def error_message(:already_used), do: "The verification was already used. Please try again."
  def error_message(:wrong_answer), do: "The verification answer was incorrect. Please try again."
  def error_message(_), do: "The verification failed. Please try again."

  # Accepts either the full form params or the inner Wiztchta map.
  defp fields(%{"token" => _} = fields, _param), do: {:ok, fields}

  defp fields(params, param) when is_map(params) do
    case Map.get(params, param) do
      %{} = fields -> {:ok, fields}
      _ -> {:error, :missing}
    end
  end

  defp fields(_params, _param), do: {:error, :missing}

  defp token_and_response(%{"token" => token, "response" => response})
       when is_binary(token) and token != "" and is_binary(response) and response != "",
       do: {:ok, token, response}

  defp token_and_response(_fields), do: {:error, :missing}

  # Tokens issued before 0.2.0 have no issued_at; let them through.
  defp check_min_time(%{issued_at: issued_at}, opts) when is_integer(issued_at) do
    case Config.get(:min_time, opts) do
      min_time when is_number(min_time) and min_time > 0 ->
        elapsed_ms = System.system_time(:millisecond) - issued_at
        if elapsed_ms < min_time * 1000, do: {:error, :too_fast}, else: :ok

      _disabled ->
        :ok
    end
  end

  defp check_min_time(_payload, _opts), do: :ok

  defp consume(payload, opts) do
    case Config.get(:store, opts) do
      nil -> :ok
      false -> :ok
      store -> store.consume(payload.id, payload.expires_at, opts)
    end
  end
end
