defmodule Cldr.Currency do
  @moduledoc """
  Defines a currency structure and a set of functions to manage the validity of a currency code
  and to return metadata for currencies.
  """

  alias Cldr.Locale
  alias Cldr.LanguageTag

  @type format ::
          :standard
          | :accounting
          | :short
          | :long
          | :percent
          | :scientific

  @type code :: String.t()

  @type currency_status :: :all | :current | :historic | :tender

  @type t :: %__MODULE__{
          code: code,
          name: String.t(),
          tender: boolean,
          symbol: String.t(),
          digits: non_neg_integer,
          rounding: non_neg_integer,
          narrow_symbol: String.t(),
          cash_digits: non_neg_integer,
          cash_rounding: non_neg_integer,
          iso_digits: non_neg_integer,
          count: %{},
          from: Date.year,
          to: Date.year
        }

  defstruct code: nil,
            name: "",
            symbol: "",
            narrow_symbol: nil,
            digits: 0,
            rounding: 0,
            cash_digits: 0,
            cash_rounding: 0,
            iso_digits: 0,
            tender: false,
            count: nil,
            from: nil,
            to: nil

  @doc """
  Returns a `Currency` struct created from the arguments.

  ## Arguments

  * `currency` is a custom currency code of a format defined in ISO4217

  * `options` is a map of options representing the optional elements of
    the `%Currency{}` struct

  ## Returns

  * `{:ok, Cldr.Currency.t}` or

  * `{:error, {exception, message}}`

  ## Example

      iex> Cldr.Currency.new(:XAA)
      {:ok,
       %Cldr.Currency{cash_digits: 0, cash_rounding: 0, code: :XAA, count: nil,
        digits: 0, name: "", narrow_symbol: nil, rounding: 0, symbol: "",
        tender: false}}

      iex> Cldr.Currency.new(:ZAA, name: "Invalid Custom Name")
      {:error, {Cldr.UnknownCurrencyError, "The currency :ZAA is invalid"}}

      iex> Cldr.Currency.new("xaa", name: "Custom Name")
      {:ok,
       %Cldr.Currency{cash_digits: 0, cash_rounding: 0, code: :XAA, count: nil,
        digits: 0, name: "Custom Name", narrow_symbol: nil, rounding: 0, symbol: "",
        tender: false}}

      iex> Cldr.Currency.new(:XAA, name: "Custom Name")
      {:ok,
       %Cldr.Currency{cash_digits: 0, cash_rounding: 0, code: :XAA, count: nil,
        digits: 0, name: "Custom Name", narrow_symbol: nil, rounding: 0, symbol: "",
        tender: false}}

      iex> Cldr.Currency.new(:XBC)
      {:error, {Cldr.CurrencyAlreadyDefined, "Currency :XBC is already defined"}}

  """
  @spec new(binary | atom, map | list) :: t | {:error, binary}
  def new(currency, options \\ [])

  def new(currency, options) do
    with {:ok, currency_code} <- Cldr.validate_currency(currency),
         false <- currency_code in known_currencies() do
      {:ok, struct(@struct, [{:code, currency_code} | options])}
    else
      true ->
        {
          :error,
          {Cldr.CurrencyAlreadyDefined, "Currency #{inspect(currency)} is already defined"}
        }

      error ->
        error
    end
  end

  @doc """
  Returns the appropriate currency display name for the `currency`, based
  on the plural rules in effect for the `locale`.

  ## Arguments

  * `number` is an integer, float or `Decimal`

  * `currency` is any currency returned by `Cldr.Currency.known_currencies/0`

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  * `options` is a keyword list of options

  ## Options

  * `:locale` is any locale returned by `Cldr.Locale.new!/2`. The
    default is `Cldr.get_current_locale/1`

  ## Returns

  * `{:ok, plural_string}` or

  * `{:error, {exception, message}}`

  ## Examples

      iex> Cldr.Currency.pluralize 1, :USD, Test.Cldr
      {:ok, "US dollar"}

      iex> Cldr.Currency.pluralize 3, :USD, Test.Cldr
      {:ok, "US dollars"}

      iex> Cldr.Currency.pluralize 12, :USD, Test.Cldr, locale: "zh"
      {:ok, "美元"}

      iex> Cldr.Currency.pluralize 12, :USD, Test.Cldr, locale: "fr"
      {:ok, "dollars des États-Unis"}

      iex> Cldr.Currency.pluralize 1, :USD, Test.Cldr, locale: "fr"
      {:ok, "dollar des États-Unis"}

  """
  @spec pluralize(pos_integer, atom, Keyword.t()) ::
          {:ok, String.t()} | {:error, {Exception.t(), String.t()}}

  def pluralize(number, currency, backend, options \\ []) do
    default_options = [locale: backend.default_locale()]
    options = Keyword.merge(default_options, options)
    locale = options[:locale]

    with {:ok, currency_code} <- Cldr.validate_currency(currency),
         {:ok, locale} <- Cldr.validate_locale(locale, backend),
         {:ok, currency_data} <- currency_for_code(currency_code, backend, options) do
      counts = Map.get(currency_data, :count)
      {:ok, Module.concat(backend, Number.Cardinal).pluralize(number, locale, counts)}
    end
  end

  @doc """
  Returns a list of all known currency codes.

  ## Example

      iex> Cldr.Currency.known_currencies |> Enum.count
      303

  """
  @spec known_currencies() :: list(atom)
  def known_currencies do
    Cldr.known_currencies()
  end

  @doc """
  Returns a boolean indicating if the supplied currency code is known.

  ## Arguments

  * `currency_code` is a `binary` or `atom` representing an ISO4217
    currency code

  * `custom_currencies` is an optional list of custom currencies created by the
    `Cldr.Currency.new/2` function

  ## Returns

  * `true` or `false`

  ## Examples

      iex> Cldr.Currency.known_currency? "AUD"
      true

      iex> Cldr.Currency.known_currency? "GGG"
      false

      iex> Cldr.Currency.known_currency? :XCV
      false

      iex> Cldr.Currency.known_currency? :XCV, [%Cldr.Currency{code: :XCV}]
      true

  """
  @spec known_currency?(code, [t, ...]) :: boolean
  def known_currency?(currency_code, custom_currencies \\ []) do
    with {:ok, currency_code} <-  Cldr.validate_currency(currency_code),
          true <- currency_code in known_currencies() do
      true
    else
      {:error, _reason} -> Enum.any?(custom_currencies, &(currency_code == &1.code))
      false -> Enum.any?(custom_currencies, &(currency_code == &1.code))
    end
  end

  @doc """
  Returns a valid normalized ISO4217 format custom currency code or an error.

  Currency codes conform to the ISO4217 standard which means that any
  custom currency code must start with an "X" followed by two alphabetic
  characters.

  Note that since this function creates atoms but to a maximum of
  26 * 26 == 676 since the format permits 2 alphabetic characters only.

  ## Arguments

  * `currency_code` is a `String.t` or and `atom` representing the new
    currency code to be created

  ## Returns

  * `{:ok, currency_code}` or

  * `{:error, {exception, message}}`

  ## Examples

      iex> Cldr.Currency.make_currency_code("xzz")
      {:ok, :XZZ}

      iex> Cldr.Currency.make_currency_code("aaa")
      {:error, {Cldr.CurrencyCodeInvalid,
       "Invalid currency code \\"AAA\\".  Currency codes must start with 'X' followed by 2 alphabetic characters only."}}

  """
  @valid_currency_code Regex.compile!("^X[A-Z]{2}$")
  @spec make_currency_code(binary | atom) :: {:ok, atom} | {:error, binary}
  def make_currency_code(code) do
    currency_code =
      code
      |> to_string
      |> String.upcase()

    if String.match?(currency_code, @valid_currency_code) do
      {:ok, String.to_atom(currency_code)}
    else
      {
        :error,
        {
          Cldr.CurrencyCodeInvalid,
          "Invalid currency code #{inspect(currency_code)}.  " <>
            "Currency codes must start with 'X' followed by 2 alphabetic characters only."
        }
      }
    end
  end

  @doc """
  Returns the currency metadata for the requested currency code.

  ## Arguments

  * `currency_code` is a `binary` or `atom` representation of an
    ISO 4217 currency code.

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  * `options` is a `Keyword` list of options.

  ## Options

  * `:locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  ## Examples

      iex> Cldr.Currency.currency_for_code("AUD", Test.Cldr)
      {:ok,
        %Cldr.Currency{
          cash_digits: 2,
          cash_rounding: 0,
          code: "AUD",
          count: %{one: "Australian dollar", other: "Australian dollars"},
          digits: 2,
          iso_digits: 2,
          name: "Australian Dollar",
          narrow_symbol: "$",
          rounding: 0,
          symbol: "A$",
          tender: true
      }}

      iex> Cldr.Currency.currency_for_code("THB", Test.Cldr)
      {:ok,
        %Cldr.Currency{
          cash_digits: 2,
          cash_rounding: 0,
          code: "THB",
          count: %{one: "Thai baht", other: "Thai baht"},
          digits: 2,
          iso_digits: 2,
          name: "Thai Baht",
          narrow_symbol: "฿",
          rounding: 0,
          symbol: "THB",
          tender: true
      }}

  """
  @spec currency_for_code(code, Cldr.backend(), Keyword.t()) ::
          {:ok, t} | {:error, {Exception.t(), String.t()}}

  def currency_for_code(currency_code, backend, options \\ []) do
    default_options = [locale: backend.default_locale()]
    options = Keyword.merge(default_options, options)

    with {:ok, code} <- Cldr.validate_currency(currency_code),
         {:ok, locale} <- Cldr.validate_locale(options[:locale], backend),
         {:ok, currencies} <- currencies_for_locale(locale, backend) do
      {:ok, get_currency_metadata(code, Map.get(currencies, code))}
    end
  end

  defp get_currency_metadata(code, nil) do
    string_code = to_string(code)
    {:ok, meta} = new(code, name: string_code, symbol: string_code, narrow_symbol: string_code, count: %{other: string_code})
    meta
  end

  defp get_currency_metadata(_code, meta) do
    meta
  end

  @doc """
  Returns the currency metadata for a locale.

  """
  @spec currencies_for_locale(Locale.name() | LanguageTag.t(), Cldr.backend()) ::
          {:ok, Map.t()} | {:error, {Exception.t(), String.t()}}
  def currencies_for_locale(locale, backend) do
    Module.concat(backend, Currency).currencies_for_locale(locale)
  end

  @doc """
  Returns the string and symbols for a currency that
  can be used to parse money

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  * `currency_status` is `:all`, `:current`, `:historic` or `:tender`
    or a list of one or more status. The default is `:all`

  """
  @spec currency_strings(Cldr.Locale.t, Cldr.backend(), currency_status) :: Map.t
  def currency_strings(locale, backend, currency_status \\ :all) do
    Module.concat(backend, Currency).currency_strings(locale, currency_status)
  end

  @doc """
  Returns all currency strings for all known locales

  ## Arguments

  * `currency_status` is `:all`, `:current`, `:historic` or `:tender`
    or a list of one or more status. The default is `:all`

  """
  @spec all_currency_strings(Cldr.backend(), currency_status) :: Map.t
  def all_currency_strings(backend, currency_status \\ :all) do
    Module.concat(backend, Currency).all_currency_strings(currency_status)
  end

  @doc """
  Return only those currencies meeting the
  filter criteria.

  ## Arguments

  * `currency` is a `Cldr.Currency.t`, a list of `Cldr.Currency.t` or a
    map where the values of each item is a `Cldr.Currency.t`

  * `currency_status` is `:all`, `:current`, `:historic` or `:tender`
    or a list of one or more status. The default is `:all`

  """
  @spec currency_filter(Cldr.Currency.t | [Cldr.Currency.t] | Map.t,
    Cldr.Currency.currency_status) :: boolean

  def currency_filter(currency, currency_status)

  def currency_filter(%Cldr.Currency{} = _currency, :all) do
    true
  end

  def currency_filter(%Cldr.Currency{} = currency, :current) do
    !is_nil(currency.iso_digits) && is_nil(currency.to)
  end

  def currency_filter(%Cldr.Currency{} = currency, :historic) do
    is_nil(currency.iso_digits) ||
    (is_integer(currency.to) && currency.to < Date.utc_today.year)
  end

  def currency_filter(%Cldr.Currency{} = currency, :tender) do
    currency.tender
  end

  def currency_filter(%Cldr.Currency{} = currency, status) when is_list(status) do
    Enum.all?(status, fn s -> currency_filter(currency, s) end)
  end

  def currency_filter(currencies, currency_status) when is_map(currencies) do
    Enum.filter(currencies, fn {_m, c} -> currency_filter(c, currency_status) end)
    |> Map.new
  end

  def currency_filter(currencies, currency_status) when is_list(currencies) do
    Enum.filter(currencies, &currency_filter(&1, currency_status))
  end
end
