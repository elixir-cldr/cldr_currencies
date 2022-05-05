# Cldr Currencies

Packages the currency definitions from [CLDR](http://cldr.unicode.org) into a set of functions
to return currency data.

## Installation

The package can be installed by adding `ex_cldr_currencies` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_cldr_currencies, "~> 2.5"}
  ]
end
```

## Defining private use currencies

[ISO4217](https://en.wikipedia.org/wiki/ISO_4217) permits the creation of private use currencies. These are denoted by currencies that start with "X" followed by two characters.  New currencies can be created with `Cldr.Currency.new/2` however in order to do so a supervisor must be started which maintains an `:ets` table that holds the custom currencies.

Since the currencies are stored in an `:ets` table they are transient and will be lost on application restart. It is the developers responsibility to define the required private use currencies on application restart. One option is to use a callback function as described below.

### Starting the private use currency supervisor

The simplest way to start the private use currency supervisor is:
```elixir
iex> Cldr.Currency.start_link()
```

The preferred method however is to add the supervisor to your applications supervision tree. In your application module (ie the one that includes `use Application`):
```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    # Start the service which maintains the
    # :ets table that holds the private use currencies
    children = [
      Cldr.Currency
      ...
    ]

    opts = [strategy: :one_for_one, name: MoneyTest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Loading private use currencies at application start
If private use currencies are required then defining them when the application starts can be accomplished by providing a callback to the `Cldr.Currency` supervisor as either a `{Module, :function, args}` tuple or as an anonymous function that takes two arguments. 

The callback will be called when the custom currency supervisor is starting. The callback function is expected (but not required) to call `Cldr.Currency.new/2` to load custom currencies. Most typically this would be done to load currency definitions from a database (or other serialization) and call `Cldr.Currency.new/2` for each custom currency. In that way, any application code that depends upon the availability of custom currencies can be assured that they are available since the callback will be invoked before the application code starts.

If the callback returns `:error` or `{:error, String.t()}` then the custom currency superisor is shutdown and error is returned.

Here are some examples:
```elixir
# Using an anonymous function
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Start the service which maintains the
    # :ets table that holds the private use currencies
    children = [
      {Cldr.Currency, [callback: fn pid, table ->
        "#{inspect pid}: Starting private use currency store for #{inspect table}" end]}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# Using an MFA
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # In this example, the `pid` and `table` will be
    # prepended to the `args`. In this example therefore
    # the callback will be `MyAppModule.my_function(pid, table)`
    children = [
      {Cldr.Currency, [callback: {MyAppModule, :my_function, []}]}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

```
