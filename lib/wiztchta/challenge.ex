defmodule Wiztchta.Challenge do
  @moduledoc """
  Behaviour for challenge types, and the struct handed to templates.

  A challenge type generates a `public` map (rendered to the user) and a
  `secret` (kept inside the encrypted token), checks a response against the
  secret, and renders its own UI.

  ## Writing a challenge type

      defmodule MyApp.ColorChallenge do
        @behaviour Wiztchta.Challenge
        use Phoenix.Component

        @impl true
        def generate(_opts), do: {%{"question" => "Type the word blue"}, "blue"}

        @impl true
        def valid?(secret, response, _opts), do: String.downcase(String.trim(response)) == secret

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <label for={@id <> "-response"}>{@challenge.public["question"]}</label>
          <input type="text" id={@id <> "-response"} name={@name <> "[response]"} />
          \"\"\"
        end
      end

  `render/1` receives `@challenge` (this struct), `@id` (DOM id prefix) and
  `@name` (form param prefix). The response must be submitted as
  `@name <> "[response]"`; the token input is rendered for you.

  Secrets are stored with `:erlang.term_to_binary/1`, so keep them small.
  """

  @type t :: %__MODULE__{type: module, token: String.t(), public: map}
  @enforce_keys [:type, :token, :public]
  defstruct [:type, :token, :public]

  @doc "Returns `{public, secret}` for a new challenge."
  @callback generate(opts :: keyword) :: {public :: map, secret :: term}

  @doc "Returns whether `response` solves the challenge described by `secret`."
  @callback valid?(secret :: term, response :: String.t(), opts :: keyword) :: boolean

  @doc "Renders the challenge UI. See the module docs for available assigns."
  @callback render(assigns :: map) :: Phoenix.LiveView.Rendered.t()
end
