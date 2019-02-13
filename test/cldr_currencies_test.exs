defmodule Cldr.Currency.Test do
  use ExUnit.Case

  doctest Cldr.Currency
  doctest Test.Cldr.Currency

  test "that we can confirm known currencies" do
    assert Cldr.Currency.known_currency?("USD") == true
  end

  test "that we reject unknown currencies" do
    assert Cldr.Currency.known_currency?("ABCD") == false
  end

  test "that we filter historic currencies correctly" do
    current_currencies =
      "en"
      |> Test.Cldr.Currency.currencies_for_locale!()
      |> Cldr.Currency.currency_filter([:current])

    assert Map.get(current_currencies, :SDP) == nil
  end

  test "that we have currency effective dates" do
    historic_currencies =
      "en"
      |> Test.Cldr.Currency.currencies_for_locale!()
      |> Cldr.Currency.currency_filter([:historic])
      |> Map.keys()

    assert :ZWR in historic_currencies
    assert :YUN in historic_currencies
    assert :XFU in historic_currencies
    assert :ZRN in historic_currencies
  end

  test "names with annotations are intact" do
    assert Cldr.Currency.strings_for_currency(:USN, "en", Test.Cldr) ==
     ["us dollar (next day)", "usn", "us dollars (next day)"]
  end

  test "currency strings is a map" do
    {:ok, strings} = Test.Cldr.Currency.currency_strings("en")
    assert is_map(strings)
  end
end
