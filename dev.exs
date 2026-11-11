# Demo app for developing Wiztchta. Run with:
#
#     mix dev        # or: iex -S mix dev
#
# then open http://localhost:4000. Not part of the published package.

Logger.configure(level: :info)

Application.put_env(:wiztchta, Demo.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  adapter: Bandit.PhoenixAdapter,
  server: true,
  debug_errors: true,
  check_origin: false,
  secret_key_base: String.duplicate("wiztchta-demo-secret-", 4),
  live_view: [signing_salt: "wiztchta-demo"],
  pubsub_server: Demo.PubSub
)

Application.put_env(:wiztchta, :endpoint, Demo.Endpoint)

defmodule Demo.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>Wiztchta demo</title>
        <script type="importmap" phx-no-curly-interpolation>
          {"imports": {
            "phoenix": "/assets/phoenix/phoenix.mjs",
            "phoenix_live_view": "/assets/phoenix_live_view/phoenix_live_view.esm.js",
            "wiztchta": "/assets/wiztchta/wiztchta.js"
          }}
        </script>
        <script type="module" src="/demo/demo.js">
        </script>
        <link rel="stylesheet" href="/demo/demo.css" />
      </head>
      <body>
        <nav>
          <a href="/">LiveView</a> · <a href="/classic">Controller</a>
        </nav>
        {@inner_content}
      </body>
    </html>
    """
  end
end

defmodule Demo.FormLive do
  use Phoenix.LiveView
  import Wiztchta.Components

  alias Wiztchta.Challenges.{Math, ProofOfWork}

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"email" => ""}, as: :signup),
       type: ProofOfWork,
       challenge: Wiztchta.new(type: ProofOfWork),
       result: nil
     )}
  end

  def handle_event("type", %{"type" => type}, socket) do
    type = if type == "math", do: Math, else: ProofOfWork
    {:noreply, assign(socket, type: type, challenge: Wiztchta.new(type: type), result: nil)}
  end

  def handle_event("save", params, socket) do
    result = Wiztchta.verify(params)

    {:noreply,
     assign(socket,
       result: result,
       challenge: Wiztchta.new(type: socket.assigns.type),
       form: to_form(params["signup"] || %{}, as: :signup)
     )}
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>LiveView form</h1>
      <p>
        Challenge: <button id="type-pow" phx-click="type" phx-value-type="pow">Proof of work</button>
        <button id="type-math" phx-click="type" phx-value-type="math">Math</button>
      </p>
      <.form for={@form} id="signup-form" phx-submit="save">
        <label for="signup_email">Email</label>
        <input type="email" name={@form[:email].name} id="signup_email" value={@form[:email].value} />
        <.wiztchta challenge={@challenge} id="signup-captcha" />
        <button type="submit" id="signup-submit">Sign up</button>
      </.form>
      <.result result={@result} />
    </main>
    """
  end

  attr :result, :any

  def result(%{result: nil} = assigns), do: ~H""
  def result(%{result: :ok} = assigns), do: ~H|<p id="result" class="ok">Verified ✓</p>|

  def result(%{result: {:error, reason}} = assigns) do
    assigns = assign(assigns, :message, Wiztchta.error_message(reason))
    ~H|<p id="result" class="error">{@message}</p>|
  end
end

defmodule Demo.ClassicHTML do
  use Phoenix.Component
  import Wiztchta.Components

  def contact(assigns) do
    ~H"""
    <main>
      <h1>Controller form (no LiveView)</h1>
      <.form for={%{}} as={:contact} id="contact-form" action="/classic">
        <label for="contact_message">Message</label>
        <textarea name="contact[message]" id="contact_message"></textarea>
        <.wiztchta id="contact-captcha" type={Wiztchta.Challenges.ProofOfWork} />
        <button type="submit" id="contact-submit">Send</button>
      </.form>
      <Demo.FormLive.result result={@result} />
    </main>
    """
  end
end

defmodule Demo.ClassicController do
  use Phoenix.Controller, formats: [:html]

  plug Wiztchta.Plug when action in [:create]

  def new(conn, _params), do: render_form(conn, nil)
  def create(conn, _params), do: render_form(conn, conn.assigns.wiztchta)

  defp render_form(conn, result) do
    conn |> put_view(html: Demo.ClassicHTML) |> render(:contact, result: result)
  end
end

defmodule Demo.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {Demo.Layouts, :root}
    plug :protect_from_forgery
  end

  scope "/" do
    pipe_through :browser
    live "/", Demo.FormLive
    get "/classic", Demo.ClassicController, :new
    post "/classic", Demo.ClassicController, :create
  end
end

defmodule Demo.Endpoint do
  use Phoenix.Endpoint, otp_app: :wiztchta

  @session [store: :cookie, key: "_wiztchta_demo", signing_salt: "wiztchta-demo"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session]]

  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}
  plug Plug.Static, at: "/assets/phoenix_live_view", from: {:phoenix_live_view, "priv/static"}
  plug Plug.Static, at: "/assets/wiztchta", from: {:wiztchta, "priv/static"}
  plug Plug.Static, at: "/demo", from: Path.expand("dev", __DIR__)

  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason
  plug Plug.Session, @session
  plug Demo.Router
end

{:ok, _} =
  Supervisor.start_link(
    [{Phoenix.PubSub, name: Demo.PubSub}, Demo.Endpoint],
    strategy: :one_for_one
  )

IO.puts("Wiztchta demo running at http://localhost:#{Demo.Endpoint.config(:http)[:port]}")
