defmodule Cldr.Currency.Test do
  use ExUnit.Case

  doctest Cldr.Currency
  doctest MyApp.Cldr.Currency

  setup do
    Cldr.Currency.start_link()
    :ok
  end

  test "that we can confirm known currencies" do
    assert Cldr.Currency.known_currency_code?("USD") == true
  end

  test "that we reject unknown currencies" do
    assert Cldr.Currency.known_currency_code?("ABCD") == false
  end

  test "that we filter historic currencies correctly" do
    current_currencies =
      "en"
      |> MyApp.Cldr.Currency.currencies_for_locale!()
      |> Cldr.Currency.currency_filter([:current])

    assert Map.get(current_currencies, :SDP) == nil
  end

  test "that we have currency effective dates" do
    historic_currencies =
      "en"
      |> MyApp.Cldr.Currency.currencies_for_locale!()
      |> Cldr.Currency.currency_filter([:historic])
      |> Map.keys()

    assert :ZWR in historic_currencies
    assert :YUN in historic_currencies
    assert :XFU in historic_currencies
    assert :ZRN in historic_currencies
  end

  test "names with annotations are intact" do
    assert Cldr.Currency.strings_for_currency(:USN, "en", MyApp.Cldr) ==
     ["us dollar (next day)", "usn", "us dollars (next day)"]
  end

  test "currency strings is a map" do
    {:ok, strings} = MyApp.Cldr.Currency.currency_strings("en")
    assert is_map(strings)
  end

  test "that no module docs are generated for a backend" do
    assert {:docs_v1, _, :elixir, _, :hidden, %{}, _} = Code.fetch_docs(NoDoc.Cldr.Currency)
  end

  test "that module docs are generated for a backend" do
    {:docs_v1, 3, :elixir, "text/markdown", _, %{}, _} = Code.fetch_docs(MyApp.Cldr.Currency)
  end

  test "Cldr.Chars protocol" do
    {:ok, currency} = Cldr.Currency.currency_for_code(:AUD, MyApp.Cldr)
    assert Cldr.to_string(currency) == "Australian Dollar"
  end

  test "String.Chars protocol" do
    {:ok, currency} = Cldr.Currency.currency_for_code(:AUD, MyApp.Cldr)
    assert to_string(currency) == "Australian Dollar"
  end
end
