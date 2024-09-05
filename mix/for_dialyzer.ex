defmodule Cldr.Currency.ForDialyzer do
  @moduledoc false

  def for_dialyzer do
    a = Cldr.Currency.currency_for_code("AUD")
    b = Cldr.Currency.currency_for_code(:AUD)
    {a, b}
  end

end