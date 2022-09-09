defmodule Phoenix.LiveView do
  @moduledoc ~S'''
  LiveView provides rich, real-time user experiences with
  server-rendered HTML.

  The LiveView programming model is declarative: instead of
  saying "once event X happens, change Y on the page",
  events in LiveView are regular messages which may cause
  changes to its state. Once the state changes, LiveView will
  re-render the relevant parts of its HTML template and push it
  to the browser, which updates itself in the most efficient
  manner. This means developers write LiveView templates as
  any other server-rendered HTML and LiveView does the hard
  work of tracking changes and sending the relevant diffs to
  the browser.

  At the end of the day, a LiveView is nothing more than a
  process that receives events as messages and updates its
  state. The state itself is nothing more than functional
  and immutable Elixir data structures. The events are either
  internal application messages (usually emitted by `Phoenix.PubSub`)
  or sent by the client/browser.

  LiveView is first rendered statically as part of regular
  HTTP requests, which provides quick times for "First Meaningful
  Paint", in addition to helping search and indexing engines.
  Then a persistent connection is established between client and
  server. This allows LiveView applications to react faster to user
  events as there is less work to be done and less data to be sent
  compared to stateless requests that have to authenticate, decode, load,
  and encode data on every request. The flipside is that LiveView
  uses more memory on the server compared to stateless requests.

  ## Life-cycle

  A LiveView begins as a regular HTTP request and HTML response,
  and then upgrades to a stateful view on client connect,
  guaranteeing a regular HTML page even if JavaScript is disabled.
  Any time a stateful view changes or updates its socket assigns, it is
  automatically re-rendered and the updates are pushed to the client.

  You begin by rendering a LiveView typically from your router.
  When LiveView is first rendered, the `c:mount/3` callback is invoked
  with the current params, the current session and the LiveView socket.
  As in a regular request, `params` contains public data that can be
  modified by the user. The `session` always contains private data set
  by the application itself. The `c:mount/3` callback wires up socket
  assigns necessary for rendering the view. After mounting, `c:handle_params/3`
  is invoked so uri and query params are handled. Finally, `c:render/1`
  is invoked and the HTML is sent as a regular HTML response to the
  client.

  After rendering the static page, LiveView connects from the client
  to the server where stateful views are spawned to push rendered updates
  to the browser, and receive client events via `phx-` bindings. Just like
  the first rendering, `c:mount/3`, is invoked  with params, session,
  and socket state, However in the connected client case, a LiveView process
  is spawned on the server, runs `c:handle_params/3` again and then pushes
  the result of `c:render/1` to the client and continues on for the duration
  of the connection. If at any point during the stateful life-cycle a crash
  is encountered, or the client connection drops, the client gracefully
  reconnects to the server, calling `c:mount/3` and `c:handle_params/3` again.

  LiveView also allows attaching hooks to specific life-cycle stages with
  `attach_hook/4`.

  ## Example

  Before writing your first example, make sure that Phoenix LiveView
  is properly installed. If you are just getting started, this can
  be easily done by running `mix phx.new my_app --live`. The `phx.new`
  command with the `--live` flag will create a new project with
  LiveView installed and configured. Otherwise, please follow the steps
  in the [installation guide](installation.md) before continuing.

  A LiveView is a simple module that requires two callbacks: `c:mount/3`
  and `c:render/1`:

      defmodule MyAppWeb.ThermostatLive do
        # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
        use Phoenix.LiveView

        def render(assigns) do
          ~H"""
          Current temperature: <%= @temperature %>
          """
        end

        def mount(_params, %{"current_user_id" => user_id}, socket) do
          temperature = Thermostat.get_user_reading(user_id)
          {:ok, assign(socket, :temperature, temperature)}
        end
      end

  The `c:render/1` callback receives the `socket.assigns` and is responsible
  for returning rendered content. We use the `~H` sigil to define a HEEx
  template, which stands for HTML+EEx. They are an extension of Elixir's
  builtin EEx templates, with support for HTML validation, syntax-based
  components, smart change tracking, and more. You can learn more about
  the template syntax in `Phoenix.LiveView.Helpers.sigil_H/2`.

  Next, decide where you want to use your LiveView.

  You can serve the LiveView directly from your router (recommended):

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", MyAppWeb do
          live "/thermostat", ThermostatLive
        end
      end

  *Note:* the above assumes there is `plug :put_root_layout` call
  in your router that configures the LiveView layout. This call is
  automatically included in Phoenix v1.6 apps and described in
  the installation guide.

  Alternatively, you can `live_render` from any template. In your view:

      import Phoenix.LiveView.Helpers

  Then in your template:

      <h1>Temperature Control</h1>
      <%= live_render(@conn, MyAppWeb.ThermostatLive) %>

  Once the LiveView is rendered, a regular HTML response is sent. In your
  app.js file, you should find the following:

      import {Socket} from "phoenix"
      import {LiveSocket} from "phoenix_live_view"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
      liveSocket.connect()

  After the client connects, `c:mount/3` will be invoked inside a spawned
  LiveView process. At this point, you can use `connected?/1` to
  conditionally perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc. For example, you can periodically update a LiveView
  with a timer:

      defmodule DemoWeb.ThermostatLive do
        use Phoenix.LiveView
        ...

        def mount(_params, %{"current_user_id" => user_id}, socket) do
          if connected?(socket), do: Process.send_after(self(), :update, 30000)

          case Thermostat.get_user_reading(user_id) do
            {:ok, temperature} ->
              {:ok, assign(socket, temperature: temperature, user_id: user_id)}

            {:error, _reason} ->
              {:ok, redirect(socket, to: "/error")}
          end
        end

        def handle_info(:update, socket) do
          Process.send_after(self(), :update, 30000)
          {:ok, temperature} = Thermostat.get_reading(socket.assigns.user_id)
          {:noreply, assign(socket, :temperature, temperature)}
        end
      end

  We used `connected?(socket)` on mount to send our view a message every 30s if
  the socket is in a connected state. We receive the `:update` message in the
  `c:handle_info/2` callback, just like in an Elixir `GenServer`, and update our
  socket assigns. Whenever a socket's assigns change, `c:render/1` is automatically
  invoked, and the updates are sent to the client.

  ## Colocating templates

  In the examples above, we have placed the template directly inside the
  LiveView:

      defmodule MyAppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~H"""
          Current temperature: <%= @temperature %>
          """
        end

  For larger templates, you can place them in a file in the same directory
  and same name as the LiveView. For example, if the file above is placed
  at `lib/my_app_web/live/thermostat_live.ex`, you can also remove the
  `c:render/1` definition above and instead put the template code at
  `lib/my_app_web/live/thermostat_live.html.heex`.

  Alternatively, you can keep the `c:render/1` callback but delegate to an
  existing `Phoenix.View` module in your application. For example:

      defmodule MyAppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          Phoenix.View.render(MyAppWeb.PageView, "page.html", assigns)
        end
      end

  In all cases, each assign in the template will be accessible as `@assign`.
  You can learn more about [assigns and HEEx templates in their own guide](assigns-eex.md).

  ## Bindings

  Phoenix supports DOM element bindings for client-server interaction. For
  example, to react to a click on a button, you would render the element:

      <button phx-click="inc_temperature">+</button>

  Then on the server, all LiveView bindings are handled with the `c:handle_event/3`
  callback, for example:

      def handle_event("inc_temperature", _value, socket) do
        {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
        {:noreply, assign(socket, :temperature, new_temp)}
      end

  To update UI state, for example, to open and close dropdowns, switch tabs,
  etc, LiveView also supports JS commands (`Phoenix.LiveView.JS`), which
  execute directly on the client without reaching the server. To learn more,
  see [our bindings page](bindings.md) for a complete list of all LiveView
  bindings as well as our [JavaScript interoperability guide](js-interop.md).

  ## Compartmentalize state, markup, and events in LiveView

  LiveView supports two extension mechanisms: function components, provided by
  `HEEx` templates, and stateful components.

  Function components are any function that receives an assigns map, similar
  to `render(assigns)` in our LiveView, and returns a `~H` template. For example:

      def weather_greeting(assigns) do
        ~H"""
        <div title="My div" class={@class}>
          <p>Hello <%= @name %></p>
          <MyApp.Weather.city name="Kraków"/>
        </div>
        """
      end

  You can learn more about function components in the `Phoenix.Component`
  module. At the end of the day, they are useful mechanism to reuse markup
  in your LiveViews.

  However, sometimes you need to compartmentalize or reuse more than markup.
  Perhaps you want to move part of the state or part of the events in your
  LiveView to a separate module. For these cases, LiveView provides
  `Phoenix.LiveComponent`, which are rendered using
  [`live_component/1`](`Phoenix.LiveView.Helpers.live_component/1`):

      <.live_component module={UserComponent} id={user.id} user={user} />

  Components have their own `c:mount/3` and `c:handle_event/3` callbacks, as
  well as their own state with change tracking support. Components are also
  lightweight as they "run" in the same process as the parent `LiveView`.
  However, this means an error in a component would cause the whole view to
  fail to render. See `Phoenix.LiveComponent` for a complete rundown on components.

  Finally, if you want complete isolation between parts of a LiveView, you can
  always render a LiveView inside another LiveView by calling
  [`live_render/3`](`Phoenix.LiveView.Helpers.live_render/3`). This child LiveView
  runs in a separate process than the parent, with its own callbacks. If a child
  LiveView crashes, it won't affect the parent. If the parent crashes, all children
  are terminated.

  When rendering a child LiveView, the `:id` option is required to uniquely
  identify the child. A child LiveView will only ever be rendered and mounted
  a single time, provided its ID remains unchanged.

  Given that a LiveView runs on its own process, it is an excellent tool for creating
  completely isolated UI elements, but it is a slightly expensive abstraction if
  all you want is to compartmentalize markup or events (or both).

  To sum it up:

    * use `Phoenix.Component` to compartmentalize/reuse markup
    * use `Phoenix.LiveComponent` to compartmentalize state, markup, and events
    * use nested `Phoenix.LiveView` to compartmentalize state, markup, events, and error isolation

  ## Endpoint configuration

  LiveView accepts the following configuration in your endpoint under
  the `:live_view` key:

    * `:signing_salt` (required) - the salt used to sign data sent
      to the client

    * `:hibernate_after` (optional) - the idle time in milliseconds allowed in
    the LiveView before compressing its own memory and state.
    Defaults to 15000ms (15 seconds)

  ## Guides

  LiveView has many guides to help you on your journey.

  ### Server-side

  These guides focus on server-side functionality:

    * [Assigns and HEEx templates](assigns-eex.md)
    * [Error and exception handling](error-handling.md)
    * [Live Layouts](live-layouts.md)
    * [Live Navigation](live-navigation.md)
    * [Security considerations of the LiveView model](security-model.md)
    * [Telemetry](telemetry.md)
    * [Uploads](uploads.md)
    * [Using Gettext for internationalization](using-gettext.md)

  ### Client-side

  These guides focus on LiveView bindings and client-side integration:

    * [Bindings](bindings.md)
    * [Form bindings](form-bindings.md)
    * [DOM patching and temporary assigns](dom-patching.md)
    * [JavaScript interoperability](js-interop.md)
    * [Uploads (External)](uploads-external.md)
  '''

  alias Phoenix.LiveView.Socket

  @type unsigned_params :: map

  @doc """
  The LiveView entry-point.

  For each LiveView in the root of a template, `c:mount/3` is invoked twice:
  once to do the initial page load and again to establish the live socket.

  It expects three arguments:

    * `params` - a map of string keys which contain public information that
      can be set by the user. The map contains the query params as well as any
      router path parameter. If the LiveView was not mounted at the router,
      this argument is the atom `:not_mounted_at_router`
    * `session` - the connection session
    * `socket` - the LiveView socket

  It must return either `{:ok, socket}` or `{:ok, socket, options}`, where
  `options` is one of:

    * `:temporary_assigns` - a keyword list of assigns that are temporary
      and must be reset to their value after every render. Note that once
      the value is reset, it won't be re-rendered again until it is explicitly
      assigned

    * `:layout` - the optional layout to be used by the LiveView

  """
  @callback mount(
              params :: unsigned_params() | :not_mounted_at_router,
              session :: map,
              socket :: Socket.t()
            ) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @doc """
  Renders a template.

  This callback is invoked whenever LiveView detects
  new content must be rendered and sent to the client.

  If you define this function, it must return a template
  defined via the `Phoenix.LiveView.Helpers.sigil_H/2`.

  If you don't define this function, LiveView will attempt
  to render a template in the same directory as your LiveView.
  For example, if you have a LiveView named `MyApp.MyCustomView`
  inside `lib/my_app/live_views/my_custom_view.ex`, Phoenix
  will look for a template at `lib/my_app/live_views/my_custom_view.html.heex`.
  """
  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Invoked when the LiveView is terminating.

  In case of errors, this callback is only invoked if the LiveView
  is trapping exits. See `c:GenServer.terminate/2` for more info.
  """
  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @doc """
  Invoked after mount and whenever there is a live patch event.

  It receives the current `params`, including parameters from
  the router, the current `uri` from the client and the `socket`.
  It is invoked after mount or whenever there is a live navigation
  event caused by `push_patch/2` or `Phoenix.LiveView.Helpers.live_patch/2`.

  It must always return `{:noreply, socket}`, where `:noreply`
  means no additional information is sent to the client.
  """
  @callback handle_params(unsigned_params(), uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @doc """
  Invoked to handle events sent by the client.

  It receives the `event` name, the event payload as a map,
  and the socket.

  It must return `{:noreply, socket}`, where `:noreply` means
  no additional information is sent to the client, or
  `{:reply, map(), socket}`, where the given `map()` is encoded
  and sent as a reply to the client.
  """
  @callback handle_event(event :: binary, unsigned_params(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, map, Socket.t()}

  @doc """
  Invoked to handle calls from other Elixir processes.

  See `GenServer.call/3` and `c:GenServer.handle_call/3`
  for more information.
  """
  @callback handle_call(msg :: term, {pid, reference}, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()}

  @doc """
  Invoked to handle casts from other Elixir processes.

  See `GenServer.cast/2` and `c:GenServer.handle_cast/2`
  for more information. It must always return `{:noreply, socket}`,
  where `:noreply` means no additional information is sent
  to the process which cast the message.
  """
  @callback handle_cast(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @doc """
  Invoked to handle messages from other Elixir processes.

  See `Kernel.send/2` and `c:GenServer.handle_info/2`
  for more information. It must always return `{:noreply, socket}`,
  where `:noreply` means no additional information is sent
  to the process which sent the message.
  """
  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 3,
                      terminate: 2,
                      handle_params: 3,
                      handle_event: 3,
                      handle_call: 3,
                      handle_info: 2,
                      handle_cast: 2

  @doc """
  Uses LiveView in the current module to mark it a LiveView.

      use Phoenix.LiveView,
        namespace: MyAppWeb,
        container: {:tr, class: "colorized"},
        layout: {MyAppWeb.LayoutView, "live.html"}

  ## Options

    * `:namespace` - configures the namespace the `LiveView` is in
    * `:container` - configures the container the `LiveView` will be wrapped in
    * `:layout` - configures the layout the `LiveView` will be rendered in

  """
  defmacro __using__(opts) do
    # Expand layout if possible to avoid compile-time dependencies
    opts =
      with true <- Keyword.keyword?(opts),
           {layout, template} <- Keyword.get(opts, :layout) do
        layout = Macro.expand(layout, %{__CALLER__ | function: {:__live__, 0}})
        Keyword.replace!(opts, :layout, {layout, template})
      else
        _ -> opts
      end

    quote bind_quoted: [opts: opts] do
      @behaviour Phoenix.LiveView
      use Phoenix.Component

      require Phoenix.LiveView.Renderer
      @before_compile Phoenix.LiveView.Renderer

      @phoenix_live_opts opts
      Module.register_attribute(__MODULE__, :phoenix_live_mount, accumulate: true)
      @before_compile Phoenix.LiveView
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :phoenix_live_opts)

    layout =
      case opts[:layout] do
        {mod, template} when is_atom(mod) and is_binary(template) ->
          {mod, template}

        nil ->
          nil

        other ->
          raise ArgumentError,
                ":layout expects a tuple of the form {MyLayoutView, \"my_template.html\"}, " <>
                  "got: #{inspect(other)}"
      end

    phoenix_live_mount = Module.get_attribute(env.module, :phoenix_live_mount)
    lifecycle = Phoenix.LiveView.Lifecycle.mount(env.module, phoenix_live_mount)

    namespace =
      opts[:namespace] || env.module |> Module.split() |> Enum.take(1) |> Module.concat()

    name = env.module |> Atom.to_string() |> String.replace_prefix("#{namespace}.", "")
    container = opts[:container] || {:div, []}

    live = %{
      container: container,
      name: name,
      kind: :view,
      module: env.module,
      layout: layout,
      lifecycle: lifecycle
    }

    quote do
      @doc false
      def __live__ do
        unquote(Macro.escape(live))
      end
    end
  end

  @doc """
  Declares a module callback to be invoked on the LiveView's mount.

  The function within the given module, which must be named `on_mount`,
  will be invoked before both disconnected and connected mounts. The hook
  has the option to either halt or continue the mounting process as usual.
  If you wish to redirect the LiveView, you **must** halt, otherwise an error
  will be raised.

  Tip: if you need to define multiple `on_mount` callbacks, avoid defining
  multiple modules. Instead, pass a tuple and use pattern matching to handle
  different cases:

      def on_mount(:admin, _params, _session, socket) do
        {:cont, socket}
      end

      def on_mount(:user, _params, _session, socket) do
        {:cont, socket}
      end

  And then invoke it as:

      on_mount {MyAppWeb.SomeHook, :admin}
      on_mount {MyAppWeb.SomeHook, :user}

  Registering `on_mount` hooks can be useful to perform authentication
  as well as add custom behaviour to other callbacks via `attach_hook/4`.

  ## Examples

  The following is an example of attaching a hook via
  `Phoenix.LiveView.Router.live_session/3`:

      # lib/my_app_web/live/init_assigns.ex
      defmodule MyAppWeb.InitAssigns do
        @moduledoc "\""
        Ensures common `assigns` are applied to all LiveViews attaching this hook.
        "\""
        import Phoenix.LiveView

        def on_mount(:default, _params, _session, socket) do
          {:cont, assign(socket, :page_title, "DemoWeb")}
        end

        def on_mount(:user, params, session, socket) do
          # code
        end

        def on_mount(:admin, params, session, socket) do
          # code
        end
      end

      # lib/my_app_web/router.ex
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        # pipelines, plugs, etc.

        live_session :default, on_mount: MyAppWeb.InitAssigns do
          scope "/", MyAppWeb do
            pipe_through :browser
            live "/", PageLive, :index
          end
        end

        live_session :authenticated, on_mount: {MyAppWeb.InitAssigns, :user} do
          scope "/", MyAppWeb do
            pipe_through [:browser, :require_user]
            live "/profile", UserLive.Profile, :index
          end
        end

        live_session :admins, on_mount: {MyAppWeb.InitAssigns, :admin} do
          scope "/admin", MyAppWeb.Admin do
            pipe_through [:browser, :require_user, :require_admin]
            live "/", AdminLive.Index, :index
          end
        end
      end

  """
  defmacro on_mount(mod_or_mod_arg) do
    mod_or_mod_arg =
      if Macro.quoted_literal?(mod_or_mod_arg) do
        Macro.prewalk(mod_or_mod_arg, &expand_alias(&1, __CALLER__))
      else
        mod_or_mod_arg
      end

    quote do
      Module.put_attribute(
        __MODULE__,
        :phoenix_live_mount,
        Phoenix.LiveView.Lifecycle.on_mount(__MODULE__, unquote(mod_or_mod_arg))
      )
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:on_mount, 4}})

  defp expand_alias(other, _env), do: other

  @doc """
  Returns true if the socket is connected.

  Useful for checking the connectivity status when mounting the view.
  For example, on initial page render, the view is mounted statically,
  rendered, and the HTML is sent to the client. Once the client
  connects to the server, a LiveView is then spawned and mounted
  statefully within a process. Use `connected?/1` to conditionally
  perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc.

  ## Examples

      defmodule DemoWeb.ClockLive do
        use Phoenix.LiveView
        ...
        def mount(_params, _session, socket) do
          if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

          {:ok, assign(socket, date: :calendar.local_time())}
        end

        def handle_info(:tick, socket) do
          {:noreply, assign(socket, date: :calendar.local_time())}
        end
      end
  """
  def connected?(%Socket{transport_pid: transport_pid}), do: transport_pid != nil

  @doc ~S'''
  Assigns the given `key` with value from `fun` into `socket_or_assigns` if
  one does not yet exist.

  The first argument is either a LiveView `socket` or an `assigns` map from
  function components.

  This function is useful for lazily assigning values and referencing parent
  assigns. We will cover both use cases next.

  ## Lazy assigns

  Imagine you have a function component that accepts a color:

      <.my_component color="red" />

  The color is also optional, so you can skip it:

      <.my_component />

  In such cases, the implementation can use `assign_new` to lazily
  assign a color if none is given. Let's make it so it picks a random one
  when none is given:

      def my_component(assigns) do
        assigns = assign_new(assigns, :color, fn -> Enum.random(~w(red green blue)) end)

        ~H"""
        <div class={"bg-#{@color}"}>
          Example
        </div>
        """
      end

  ## Referencing parent assigns

  When a user first accesses an application using LiveView, the LiveView is first
  rendered in its disconnected state, as part of a regular HTML response. In some
  cases, there may be data that is shared by your Plug pipelines and your LiveView,
  such as the `:current_user` assign.

  By using `assign_new` in the mount callback of your LiveView, you can instruct
  LiveView to re-use any assigns set in your Plug pipelines as part of `Plug.Conn`,
  avoiding sending additional queries to the database. Imagine you have a Plug
  that does:

      # A plug
      def authenticate(conn, _opts) do
        if user_id = get_session(conn, :user_id) do
          assign(conn, :current_user, Accounts.get_user!(user_id))
        else
          send_resp(conn, :forbidden)
        end
      end

  You can re-use the `:current_user` assign in your LiveView during the initial
  render:

      def mount(_params, %{"user_id" => user_id}, socket) do
        {:ok, assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)}
      end

  In such case `conn.assigns.current_user` will be used if present. If there is no
  such `:current_user` assign or the LiveView was mounted as part of the live
  navigation, where no Plug pipelines are invoked, then the anonymous function is
  invoked to execute the query instead.

  LiveView is also able to share assigns via `assign_new` within nested LiveView.
  If the parent LiveView defines a `:current_user` assign and the child LiveView
  also uses `assign_new/3` to fetch the `:current_user` in its `mount/3` callback,
  as above, the assign will be fetched from the parent LiveView, once again
  avoiding additional database queries.

  Note that `fun` also provides access to the previously assigned values:

      assigns =
          assigns
          |> assign_new(:foo, fn -> "foo" end)
          |> assign_new(:bar, fn %{foo: foo} -> foo <> "bar" end)
  '''
  def assign_new(socket_or_assigns, key, fun)

  def assign_new(%Socket{} = socket, key, fun) when is_function(fun, 1) do
    validate_assign_key!(key)

    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})

        Phoenix.LiveView.Utils.force_assign(
          socket,
          key,
          case assigns do
            %{^key => value} -> value
            %{} -> fun.(socket.assigns)
          end
        )

      %{assigns: assigns} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, fun.(assigns))
    end
  end

  def assign_new(%Socket{} = socket, key, fun) when is_function(fun, 0) do
    validate_assign_key!(key)

    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})
        Phoenix.LiveView.Utils.force_assign(socket, key, Map.get_lazy(assigns, key, fun))

      %{} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, fun.())
    end
  end

  def assign_new(%{__changed__: changed} = assigns, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => _} -> assigns
      %{} -> Phoenix.LiveView.Utils.force_assign(assigns, changed, key, fun.(assigns))
    end
  end

  def assign_new(%{__changed__: changed} = assigns, key, fun) when is_function(fun, 0) do
    case assigns do
      %{^key => _} -> assigns
      %{} -> Phoenix.LiveView.Utils.force_assign(assigns, changed, key, fun.())
    end
  end

  def assign_new(assigns, _key, fun) when is_function(fun, 0) or is_function(fun, 1) do
    raise_bad_socket_or_assign!("assign_new/3", assigns)
  end

  defp raise_bad_socket_or_assign!(name, assigns) do
    extra =
      case assigns do
        %_{} ->
          ""

        %{} ->
          """
          You passed an assigns map that does not have the relevant change tracking \
          information. This typically means you are calling a function component by \
          hand instead of using the HEEx template syntax. If you are using HEEx, make \
          sure you are calling a component using:

              <.component attribute={value} />

          If you are outside of HEEx and you want to test a component, use \
          Phoenix.LiveViewTest.render_component/2:

              Phoenix.LiveViewTest.render_component(&component/1, attribute: "value")

          """

        _ ->
          ""
      end

    raise ArgumentError,
          "#{name} expects a socket from Phoenix.LiveView/Phoenix.LiveComponent " <>
            " or an assigns map from Phoenix.Component as first argument, got: " <>
            inspect(assigns) <> extra
  end

  @doc """
  Adds a `key`-`value` pair to `socket_or_assigns`.

  The first argument is either a LiveView `socket` or an
  `assigns` map from function components.

  ## Examples

      iex> assign(socket, :name, "Elixir")

  """
  def assign(socket_or_assigns, key, value)

  def assign(%Socket{} = socket, key, value) do
    validate_assign_key!(key)
    Phoenix.LiveView.Utils.assign(socket, key, value)
  end

  def assign(%{__changed__: changed} = assigns, key, value) do
    case assigns do
      %{^key => ^value} ->
        assigns

      %{} ->
        Phoenix.LiveView.Utils.force_assign(assigns, changed, key, value)
    end
  end

  def assign(assigns, _key, _val) do
    raise_bad_socket_or_assign!("assign/3", assigns)
  end

  @doc """
  Adds key-value pairs to assigns.

  The first argument is either a LiveView `socket` or an
  `assigns` map from function components.

  A keyword list or a map of assigns must be given as argument
  to be merged into existing assigns.

  ## Examples

      iex> assign(socket, name: "Elixir", logo: "💧")
      iex> assign(socket, %{name: "Elixir"})

  """
  def assign(socket_or_assigns, keyword_or_map)
      when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign(acc, key, value)
    end)
  end

  defp validate_assign_key!(:flash) do
    raise ArgumentError,
          ":flash is a reserved assign by LiveView and it cannot be set directly. " <>
            "Use the appropriate flash functions instead."
  end

  defp validate_assign_key!(_key), do: :ok

  @doc """
  Updates an existing `key` with `fun` in the given `socket_or_assigns`.

  The first argument is either a LiveView `socket` or an
  `assigns` map from function components.

  The update function receives the current key's value and
  returns the updated value. Raises if the key does not exist.

  The update function may also be of arity 2, in which case it receives
  the current key's value as the first argument and the current assigns
  as the second argument. Raises if the key does not exist.

  ## Examples

      iex> update(socket, :count, fn count -> count + 1 end)
      iex> update(socket, :count, &(&1 + 1))
      iex> update(socket, :max_users_this_session, fn current_max, %{users: users} -> max(current_max, length(users)) end)
  """
  def update(socket_or_assigns, key, fun)

  def update(%Socket{assigns: assigns} = socket, key, fun) when is_function(fun, 2) do
    update(socket, key, &fun.(&1, assigns))
  end

  def update(%Socket{assigns: assigns} = socket, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => val} -> assign(socket, key, fun.(val))
      %{} -> raise KeyError, key: key, term: assigns
    end
  end

  def update(assigns, key, fun) when is_function(fun, 2) do
    update(assigns, key, &fun.(&1, assigns))
  end

  def update(assigns, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => val} -> assign(assigns, key, fun.(val))
      %{} -> raise KeyError, key: key, term: assigns
    end
  end

  def update(assigns, _key, fun) when is_function(fun, 1) or is_function(fun, 2) do
    raise_bad_socket_or_assign!("update/3", assigns)
  end

  @doc """
  Checks if the given key changed in `socket_or_assigns`.

  The first argument is either a LiveView `socket` or an
  `assigns` map from function components.

  ## Examples

      iex> changed?(socket, :count)

  """
  def changed?(socket_or_assigns, key)

  def changed?(%Socket{assigns: assigns}, key) do
    Phoenix.LiveView.Utils.changed?(assigns, key)
  end

  def changed?(%{__changed__: _} = assigns, key) do
    Phoenix.LiveView.Utils.changed?(assigns, key)
  end

  def changed?(assigns, _key) do
    raise_bad_socket_or_assign!("changed?/2", assigns)
  end

  @doc """
  Adds a flash message to the socket to be displayed.

  *Note*: While you can use `put_flash/3` inside a `Phoenix.LiveComponent`,
  components have their own `@flash` assigns. The `@flash` assign
  in a component is only copied to its parent LiveView if the component
  calls `push_redirect/2` or `push_patch/2`.

  *Note*: You must also place the `Phoenix.LiveView.Router.fetch_live_flash/2`
  plug in your browser's pipeline in place of `fetch_flash` for LiveView flash
  messages be supported, for example:

      import Phoenix.LiveView.Router

      pipeline :browser do
        ...
        plug :fetch_live_flash
      end

  ## Examples

      iex> put_flash(socket, :info, "It worked!")
      iex> put_flash(socket, :error, "You can't access that page")
  """
  defdelegate put_flash(socket, kind, msg), to: Phoenix.LiveView.Utils

  @doc """
  Clears the flash.

  ## Examples

      iex> clear_flash(socket)
  """
  defdelegate clear_flash(socket), to: Phoenix.LiveView.Utils

  @doc """
  Clears a key from the flash.

  ## Examples

      iex> clear_flash(socket, :info)
  """
  defdelegate clear_flash(socket, key), to: Phoenix.LiveView.Utils

  @doc """
  Pushes an event to the client.

  Events can be handled in two ways:

    1. They can be handled on `window` via `addEventListener`.
       A "phx:" prefix will be added to the event name.

    2. They can be handled inside a hook via `handleEvent`.

  Note that events are dispatched to all active hooks on the client who are
  handling the given `event`. If you need to scope events, then this must
  be done by namespacing them.

  ## Hook example

  If you push a "scores" event from your LiveView:

      {:noreply, push_event(socket, "scores", %{points: 100, user: "josé"})}

  A hook declared via `phx-hook` can handle it via `handleEvent`:

      this.handleEvent("scores", data => ...)

  ## `window` example

  All events are also dispatched on the `window`. This means you can handle
  them by adding listeners. For example, if you want to remove an element
  from the page, you can do this:

      {:noreply, push_event(socket, "remove-el", %{id: "foo-bar"})}

  And now in your app.js you can register and handle it:

      window.addEventListener(
        "phx:remove-el",
        e => document.getElementById(e.detail.id).remove()
      )

  """
  defdelegate push_event(socket, event, payload), to: Phoenix.LiveView.Utils

  @doc ~S"""
  Allows an upload for the provided name.

  ## Options

    * `:accept` - Required. A list of unique file type specifiers or the
      atom :any to allow any kind of file. For example, `[".jpeg"]`, `:any`, etc.

    * `:max_entries` - The maximum number of selected files to allow per
      file input. Defaults to 1.

    * `:max_file_size` - The maximum file size in bytes to allow to be uploaded.
      Defaults 8MB. For example, `12_000_000`.

    * `:chunk_size` - The chunk size in bytes to send when uploading.
      Defaults `64_000`.

    * `:chunk_timeout` - The time in milliseconds to wait before closing the
      upload channel when a new chunk has not been received. Defaults `10_000`.

    * `:external` - The 2-arity function for generating metadata for external
      client uploaders. See the Uploads section for example usage.

    * `:progress` - The optional 3-arity function for receiving progress events

    * `:auto_upload` - Instructs the client to upload the file automatically
      on file selection instead of waiting for form submits. Default false.

  Raises when a previously allowed upload under the same name is still active.

  ## Examples

      allow_upload(socket, :avatar, accept: ~w(.jpg .jpeg), max_entries: 2)
      allow_upload(socket, :avatar, accept: :any)

  For consuming files automatically as they are uploaded, you can pair `auto_upload: true` with
  a custom progress function to consume the entries as they are completed. For example:

      allow_upload(socket, :avatar, accept: :any, progress: &handle_progress/3, auto_upload: true)

      defp handle_progress(:avatar, entry, socket) do
        if entry.done? do
          uploaded_file =
            consume_uploaded_entry(socket, entry, fn %{} = meta ->
              {:ok, ...}
            end)

          {:noreply, put_flash(socket, :info, "file #{uploaded_file.name} uploaded")}
        else
          {:noreply, socket}
        end
      end
  """
  defdelegate allow_upload(socket, name, options), to: Phoenix.LiveView.Upload

  @doc """
  Revokes a previously allowed upload from `allow_upload/3`.

  ## Examples

      disallow_upload(socket, :avatar)
  """
  defdelegate disallow_upload(socket, name), to: Phoenix.LiveView.Upload

  @doc """
  Cancels an upload for the given entry.

  ## Examples

      <%= for entry <- @uploads.avatar.entries do %>
        ...
        <button phx-click="cancel-upload" phx-value-ref="<%= entry.ref %>">cancel</button>
      <% end %>

      def handle_event("cancel-upload", %{"ref" => ref}, socket) do
        {:noreply, cancel_upload(socket, :avatar, ref)}
      end
  """
  defdelegate cancel_upload(socket, name, entry_ref), to: Phoenix.LiveView.Upload

  @doc """
  Returns the completed and in progress entries for the upload.

  ## Examples

      case uploaded_entries(socket, :photos) do
        {[_ | _] = completed, []} ->
          # all entries are completed

        {[], [_ | _] = in_progress} ->
          # all entries are still in progress
      end
  """
  defdelegate uploaded_entries(socket, name), to: Phoenix.LiveView.Upload

  @doc ~S"""
  Consumes the uploaded entries.

  Raises when there are still entries in progress.
  Typically called when submitting a form to handle the
  uploaded entries alongside the form data. For form submissions,
  it is guaranteed that all entries have completed before the submit event
  is invoked. Once entries are consumed, they are removed from the upload.

  The function passed to consume may return a tagged tuple of the form
  `{:ok, my_result}` to collect results about the consumed entries, or
  `{:postpone, my_result}` to collect results, but postpone the file
  consumption to be performed later.

  ## Examples

      def handle_event("save", _params, socket) do
        uploaded_files =
          consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
            dest = Path.join("priv/static/uploads", Path.basename(path))
            File.cp!(path, dest)
            {:ok, Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")}
          end)
        {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
      end
  """
  defdelegate consume_uploaded_entries(socket, name, func), to: Phoenix.LiveView.Upload

  @doc ~S"""
  Consumes an individual uploaded entry.

  Raises when the entry is still in progress.
  Typically called when submitting a form to handle the
  uploaded entries alongside the form data. Once entries are consumed,
  they are removed from the upload.

  This is a lower-level feature than `consume_uploaded_entries/3` and useful
  for scenarios where you want to consume entries as they are individually completed.

  Like `consume_uploaded_entries/3`, the function passed to consume may return
  a tagged tuple of the form `{:ok, my_result}` to collect results about the
  consumed entries, or `{:postpone, my_result}` to collect results,
  but postpone the file consumption to be performed later.

  ## Examples

      def handle_event("save", _params, socket) do
        case uploaded_entries(socket, :avatar) do
          {[_|_] = entries, []} ->
            uploaded_files = for entry <- entries do
              consume_uploaded_entry(socket, entry, fn %{path: path} ->
                dest = Path.join("priv/static/uploads", Path.basename(path))
                File.cp!(path, dest)
                {:ok, Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")}
              end)
            end
            {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}

          _ ->
            {:noreply, socket}
        end
      end
  """
  defdelegate consume_uploaded_entry(socket, entry, func), to: Phoenix.LiveView.Upload

  @doc """
  Annotates the socket for redirect to a destination path.

  *Note*: LiveView redirects rely on instructing client
  to perform a `window.location` update on the provided
  redirect location. The whole page will be reloaded and
  all state will be discarded.

  ## Options

    * `:to` - the path to redirect to. It must always be a local path
    * `:external` - an external path to redirect to
  """
  def redirect(%Socket{} = socket, to: url) do
    validate_local_url!(url, "redirect/2")
    put_redirect(socket, {:redirect, %{to: url}})
  end

  def redirect(%Socket{} = socket, external: url) do
    put_redirect(socket, {:redirect, %{external: url}})
  end

  def redirect(%Socket{}, _) do
    raise ArgumentError, "expected :to or :external option in redirect/2"
  end

  @doc """
  Annotates the socket for navigation within the current LiveView.

  When navigating to the current LiveView, `c:handle_params/3` is
  immediately invoked to handle the change of params and URL state.
  Then the new state is pushed to the client, without reloading the
  whole page while also maintaining the current scroll position.
  For live redirects to another LiveView, use `push_redirect/2`.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_patch(socket, to: "/")}
      {:noreply, push_patch(socket, to: "/", replace: true)}

  """
  def push_patch(%Socket{} = socket, opts) do
    opts = push_opts!(opts, "push_patch/2")
    put_redirect(socket, {:live, :patch, opts})
  end

  @doc """
  Annotates the socket for navigation to another LiveView.

  The current LiveView will be shutdown and a new one will be mounted
  in its place, without reloading the whole page. This can
  also be used to remount the same LiveView, in case you want to start
  fresh. If you want to navigate to the same LiveView without remounting
  it, use `push_patch/2` instead.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_redirect(socket, to: "/")}
      {:noreply, push_redirect(socket, to: "/", replace: true)}

  """
  def push_redirect(%Socket{} = socket, opts) do
    opts = push_opts!(opts, "push_redirect/2")
    put_redirect(socket, {:live, :redirect, opts})
  end

  defp push_opts!(opts, context) do
    to = Keyword.fetch!(opts, :to)
    validate_local_url!(to, context)
    kind = if opts[:replace], do: :replace, else: :push
    %{to: to, kind: kind}
  end

  defp put_redirect(%Socket{redirected: nil} = socket, command) do
    %Socket{socket | redirected: command}
  end

  defp put_redirect(%Socket{redirected: to} = _socket, _command) do
    raise ArgumentError, "socket already prepared to redirect with #{inspect(to)}"
  end

  @invalid_local_url_chars ["\\"]

  defp validate_local_url!("//" <> _ = to, where) do
    raise_invalid_local_url!(to, where)
  end

  defp validate_local_url!("/" <> _ = to, where) do
    if String.contains?(to, @invalid_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for #{where} in URL #{inspect(to)}"
    else
      to
    end
  end

  defp validate_local_url!(to, where) do
    raise_invalid_local_url!(to, where)
  end

  defp raise_invalid_local_url!(to, where) do
    raise ArgumentError, "the :to option in #{where} expects a path but was #{inspect(to)}"
  end

  @doc """
  Accesses the connect params sent by the client for use on connected mount.

  Connect params are only sent when the client connects to the server and
  only remain available during mount. `nil` is returned when called in a
  disconnected state and a `RuntimeError` is raised if called after mount.

  ## Reserved params

  The following params have special meaning in LiveView:

    * `"_csrf_token"` - the CSRF Token which must be explicitly set by the user
      when connecting
    * `"_mounts"` - the number of times the current LiveView is mounted.
      It is 0 on first mount, then increases on each reconnect. It resets
      when navigating away from the current LiveView or on errors
    * `"_track_static"` - set automatically with a list of all href/src from
      tags with the `phx-track-static` annotation in them. If there are no
      such tags, nothing is sent

  ## Examples

      def mount(_params, _session, socket) do
        {:ok, assign(socket, width: get_connect_params(socket)["width"] || @width)}
      end
  """
  def get_connect_params(%Socket{private: private} = socket) do
    if connect_params = private[:connect_params] do
      if connected?(socket), do: connect_params, else: nil
    else
      raise_root_and_mount_only!(socket, "connect_params")
    end
  end

  @deprecated "use get_connect_info/2 instead"
  def get_connect_info(%Socket{private: private} = socket) do
    if connect_info = private[:connect_info] do
      if connected?(socket), do: connect_info, else: nil
    else
      raise_root_and_mount_only!(socket, "connect_info")
    end
  end

  @doc """
  Accesses a given connect info key from the socket.

  The following keys are supported: `:peer_data`, `:trace_context_headers`,
  `:x_headers`, `:uri`, and `:user_agent`.

  The connect information is available only during mount. During disconnected
  render, all keys are available. On connected render, only the keys explicitly
  declared in your socket are available. See `Phoenix.Endpoint.socket/3` for
  a complete description of the keys.

  ## Examples

  The first step is to declare the `connect_info` you want to receive.
  Typically, it includes at least the session, but you must include all
  other keys you want to access on connected mount, such as `:peer_data`:

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [:peer_data, session: @session_options]]

  Those values can now be accessed on the connected mount as
  `get_connect_info/2`:

      def mount(_params, _session, socket) do
        peer_data = get_connect_info(socket, :peer_data)
        {:ok, assign(socket, ip: peer_data.address)}
      end

  If the key is not available, usually because it was not specified
  in `connect_info`, it returns nil.
  """
  def get_connect_info(%Socket{private: private} = socket, key) when is_atom(key) do
    if connect_info = private[:connect_info] do
      case connect_info do
        %Plug.Conn{} -> conn_connect_info(connect_info, key)
        %{} -> connect_info[key]
      end
    else
      raise_root_and_mount_only!(socket, "connect_info")
    end
  end

  defp conn_connect_info(conn, :peer_data) do
    Plug.Conn.get_peer_data(conn)
  end

  defp conn_connect_info(conn, :x_headers) do
    for {header, _} = pair <- conn.req_headers,
        String.starts_with?(header, "x-"),
        do: pair
  end

  defp conn_connect_info(conn, :trace_context_headers) do
    for {header, _} = pair <- conn.req_headers,
        header in ["traceparent", "tracestate"],
        do: pair
  end

  defp conn_connect_info(conn, :uri) do
    %URI{
      scheme: to_string(conn.scheme),
      query: conn.query_string,
      port: conn.port,
      host: conn.host,
      path: conn.request_path
    }
  end

  defp conn_connect_info(conn, :user_agent) do
    with {_, value} <- List.keyfind(conn.req_headers, "user-agent", 0) do
      value
    end
  end

  @doc """
  Returns true if the socket is connected and the tracked static assets have changed.

  This function is useful to detect if the client is running on an outdated
  version of the marked static files. It works by comparing the static paths
  sent by the client with the one on the server.

  **Note:** this functionality requires Phoenix v1.5.2 or later.

  To use this functionality, the first step is to annotate which static files
  you want to be tracked by LiveView, with the `phx-track-static`. For example:

      <link phx-track-static rel="stylesheet" href="<%= Routes.static_path(@conn, "/css/app.css") %>"/>
      <script defer phx-track-static type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>

  Now, whenever LiveView connects to the server, it will send a copy `src`
  or `href` attributes of all tracked statics and compare those values with
  the latest entries computed by `mix phx.digest` in the server.

  The tracked statics on the client will match the ones on the server the
  huge majority of times. However, if there is a new deployment, those values
  may differ. You can use this function to detect those cases and show a
  banner to the user, asking them to reload the page. To do so, first set the
  assign on mount:

      def mount(params, session, socket) do
        {:ok, assign(socket, static_changed?: static_changed?(socket))}
      end

  And then in your views:

      <%= if @static_changed? do %>
        <div id="reload-static">
          The app has been updated. Click here to <a href="#" onclick="window.location.reload()">reload</a>.
        </div>
      <% end %>

  If you prefer, you can also send a JavaScript script that immediately
  reloads the page.

  **Note:** only set `phx-track-static` on your own assets. For example, do
  not set it in external JavaScript files:

      <script defer phx-track-static type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>

  Because you don't actually serve the file above, LiveView will interpret
  the static above as missing, and this function will return true.
  """
  def static_changed?(%Socket{private: private, endpoint: endpoint} = socket) do
    if connect_params = private[:connect_params] do
      connected?(socket) and
        static_changed?(
          connect_params["_track_static"],
          endpoint.config(:cache_static_manifest_latest)
        )
    else
      raise_root_and_mount_only!(socket, "static_changed?")
    end
  end

  defp static_changed?([_ | _] = statics, %{} = latest) do
    latest = Map.to_list(latest)

    not Enum.all?(statics, fn static ->
      [static | _] = :binary.split(static, "?")

      Enum.any?(latest, fn {non_digested, digested} ->
        String.ends_with?(static, non_digested) or String.ends_with?(static, digested)
      end)
    end)
  end

  defp static_changed?(_, _), do: false

  defp raise_root_and_mount_only!(socket, fun) do
    if child?(socket) do
      raise RuntimeError, """
      attempted to read #{fun} from a nested child LiveView #{inspect(socket.view)}.

      Only the root LiveView has access to #{fun}.
      """
    else
      raise RuntimeError, """
      attempted to read #{fun} outside of #{inspect(socket.view)}.mount/3.

      #{fun} only exists while mounting. If you require access to this information
      after mount, store the state in socket assigns.
      """
    end
  end

  @doc """
  Asynchronously updates a `Phoenix.LiveComponent` with new assigns.

  The `:id` that identifies the component must be passed as part of the
  assigns and it will be used to identify the live components to be updated.

  The `pid` argument is optional and it defaults to the current process,
  which means the update instruction will be sent to a component running
  on the same LiveView. If the current process is not a LiveView or you
  want to send updates to a live component running on another LiveView,
  you should explicitly pass the LiveView's pid instead.

  When the component receives the update, first the optional
  [`preload/1`](`c:Phoenix.LiveComponent.preload/1`) then
  [`update/2`](`c:Phoenix.LiveComponent.update/2`) is invoked with the new assigns.
  If [`update/2`](`c:Phoenix.LiveComponent.update/2`) is not defined
  all assigns are simply merged into the socket.

  While a component may always be updated from the parent by updating some
  parent assigns which will re-render the child, thus invoking
  [`update/2`](`c:Phoenix.LiveComponent.update/2`) on the child component,
  `send_update/3` is useful for updating a component that entirely manages its
  own state, as well as messaging between components mounted in the same
  LiveView.

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update(Cart, id: "cart", status: "cancelled")
        {:noreply, socket}
      end

      def handle_event("cancel-order-asynchronously", _, socket) do
        ...
        pid = self()

        Task.async(fn ->
          # Do something asynchronously
          send_update(pid, Cart, id: "cart", status: "cancelled")
        end)

        {:noreply, socket}
      end
  """
  def send_update(pid \\ self(), module, assigns) when is_atom(module) and is_pid(pid) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update(pid, module, id, assigns)
  end

  @doc """
  Similar to `send_update/3` but the update will be delayed according to the given `time_in_milliseconds`.

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update_after(Cart, [id: "cart", status: "cancelled"], 3000)
        {:noreply, socket}
      end

      def handle_event("cancel-order-asynchronously", _, socket) do
        ...
        pid = self()

        Task.async(fn ->
          # Do something asynchronously
          send_update_after(pid, Cart, [id: "cart", status: "cancelled"], 3000)
        end)

        {:noreply, socket}
      end
  """
  def send_update_after(pid \\ self(), module, assigns, time_in_milliseconds)
      when is_atom(module) and is_integer(time_in_milliseconds) and is_pid(pid) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update_after. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update_after(pid, module, id, assigns, time_in_milliseconds)
  end

  @doc """
  Returns the transport pid of the socket.

  Raises `ArgumentError` if the socket is not connected.

  ## Examples

      iex> transport_pid(socket)
      #PID<0.107.0>
  """
  def transport_pid(%Socket{}) do
    case Process.get(:"$callers") do
      [transport_pid | _] -> transport_pid
      _ -> raise ArgumentError, "transport_pid/1 may only be called when the socket is connected."
    end
  end

  defp child?(%Socket{parent_pid: pid}), do: is_pid(pid)

  @doc """
  Attaches the given `fun` by `name` for the lifecycle `stage` into `socket`.

  > Note: This function is for server-side lifecycle callbacks.
  > For client-side hooks, see the
  > [JS Interop guide](js-interop.html#client-hooks).

  Hooks provide a mechanism to tap into key stages of the LiveView
  lifecycle in order to bind/update assigns, intercept events,
  patches, and regular messages when necessary, and to inject
  common functionality. Hooks may be attached to any of the following
  lifecycle stages: `:mount` (via `on_mount/1`), `:handle_params`,
  `:handle_event`, and `:handle_info`.

  ## Return Values

  Lifecycle hooks take place immediately before a given lifecycle
  callback is invoked on the LiveView. A hook may return `{:halt, socket}`
  to halt the reduction, otherwise it must return `{:cont, socket}` so
  the operation may continue until all hooks have been invoked for
  the current stage.

  ## Halting the lifecycle

  Note that halting from a hook _will halt the entire lifecycle stage_.
  This means that when a hook returns `{:halt, socket}` then the
  LiveView callback will **not** be invoked. This has some
  implications.

  ### Implications for plugin authors

  When defining a plugin that matches on specific callbacks, you **must**
  define a catch-all clause, as your hook will be invoked even for events
  you may not be interested on.

  ### Implications for end-users

  Allowing a hook to halt the invocation of the callback means that you can
  attach hooks to intercept specific events before detaching themselves,
  while allowing other events to continue normally.

  ## Examples

      def mount(_params, _session, socket) do
        socket =
          attach_hook(socket, :my_hook, :handle_event, fn
            "very-special-event", _params, socket ->
              # Handle the very special event and then detach the hook
              {:halt, detach_hook(socket, :my_hook, :handle_event)}

            _event, _params, socket ->
              {:cont, socket}
          end)

        {:ok, socket}
      end
  """
  defdelegate attach_hook(socket, name, stage, fun), to: Phoenix.LiveView.Lifecycle

  @doc """
  Detaches a hook with the given `name` from the lifecycle `stage`.

  > Note: This function is for server-side lifecycle callbacks.
  > For client-side hooks, see the
  > [JS Interop guide](js-interop.html#client-hooks).

  If no hook is found, this function is a no-op.

  ## Examples

      def handle_event(_, socket) do
        {:noreply, detach_hook(socket, :hook_that_was_attached, :handle_event)}
      end
  """
  defdelegate detach_hook(socket, name, stage), to: Phoenix.LiveView.Lifecycle
end
