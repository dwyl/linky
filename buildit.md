# build it!

This document is a log 
of our progress in building
**`linky`**.
You can follow along 
to understand every step along the way.
It serves as **_living_ documentation**
and a rapid entry point 
for anyone wanting to understand
how the app works 
so that you can easily
deploy, maintain and _contribute_ to it! 

# 1. Create a `new` `Phonenix` App

```sh
mix phx.new app --no-mailer --no-dashboard --no-gettext
```



To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`