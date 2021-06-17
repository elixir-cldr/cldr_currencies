{:ok, currency} = Cldr.Currency.currency_for_code(:AUD, MyApp.Cldr)

Benchee.run(
  %{
    "with precompiled currency" => fn ->
        Cldr.Currency.currency_for_code(currency, MyApp.Cldr)
     end,

     "without precompiled currency" => fn ->
        Cldr.Currency.currency_for_code(:AUD, MyApp.Cldr)
      end,

  },
  time: 10,
  memory_time: 2
)