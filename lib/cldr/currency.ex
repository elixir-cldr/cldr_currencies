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

  @type code :: String.t() | atom()

  @type currency_status :: :all | :current | :historic | :tender | :unannotated

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
          from: Calendar.year(),
          to: Calendar.year()
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

  alias Cldr.LanguageTag

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
  @spec new(binary | atom, map | list) :: {:ok, t} | {:error, {module(), String.t}}
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

      iex> Cldr.Currency.pluralize 1, :USD, MyApp.Cldr
      {:ok, "US dollar"}

      iex> Cldr.Currency.pluralize 3, :USD, MyApp.Cldr
      {:ok, "US dollars"}

      iex> Cldr.Currency.pluralize 12, :USD, MyApp.Cldr, locale: "zh"
      {:ok, "美元"}

      iex> Cldr.Currency.pluralize 12, :USD, MyApp.Cldr, locale: "fr"
      {:ok, "dollars des États-Unis"}

      iex> Cldr.Currency.pluralize 1, :USD, MyApp.Cldr, locale: "fr"
      {:ok, "dollar des États-Unis"}

  """
  @spec pluralize(pos_integer, code(), Cldr.backend(), Keyword.t()) ::
          {:ok, String.t()} | {:error, {module(), String.t()}}

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
  Returns the effective currency for a given locale

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  ## Returns

  * A ISO 4217 currency code as an upcased atom

  ## Examples

      iex> {:ok, locale} = Cldr.validate_locale "en", MyApp.Cldr
      iex> Cldr.Currency.currency_from_locale locale
      :USD

      iex> {:ok, locale} = Cldr.validate_locale "en-AU", MyApp.Cldr
      iex> Cldr.Currency.currency_from_locale locale
      :AUD

      iex> {:ok, locale} = Cldr.validate_locale "en-AU-u-cu-eur", MyApp.Cldr
      iex> Cldr.Currency.currency_from_locale locale
      :EUR

  """
  def currency_from_locale(%LanguageTag{locale: %{currency: nil}} = locale) do
    current_currency_for_locale(locale)
  end

  def currency_from_locale(%LanguageTag{locale: %{currency: currency}}) do
    currency
  end

  def currency_from_locale(%LanguageTag{} = locale) do
    current_currency_for_locale(locale)
  end

  @doc """
  Returns a mapping of all ISO3166 territory
  codes and a list of historic and the current
  currency for those territories.

  ## Example

      iex> Cldr.Currency.territory_currencies |> Map.get(:LT)
      %{
        EUR: %{from: ~D[2015-01-01], to: nil},
        LTL: %{from: nil, to: ~D[2014-12-31]},
        LTT: %{from: nil, to: ~D[1993-06-25]},
        SUR: %{from: nil, to: ~D[1992-10-01]}
      }

  """
  @territory_currencies Cldr.Config.territory_currency_data()
  def territory_currencies do
    @territory_currencies
  end

  def territory_currencies(territory) do
    with {:ok, territory} <- Cldr.validate_territory(territory),
         {:ok, currencies} <- Map.fetch(territory_currencies(), territory) do
      {:ok, currencies}
    else
      :error -> {:error, {Cldr.UnknownCurrencyError,
        "No currencies for #{inspect territory} were found"}}
      other -> other
    end
  end

  def territory_currencies!(territory) do
    case territory_currencies(territory) do
      {:ok, currencies} -> currencies
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  @doc """
  Returns a list of historic and the current
  currency for a given locale.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  ## Example

      iex> Cldr.Currency.currency_history_for_locale "en", MyApp.Cldr
      {:ok,
        %{
          USD: %{from: ~D[1792-01-01], to: nil},
          USN: %{tender: false},
          USS: %{from: nil, tender: false, to: ~D[2014-03-01]}
        }
      }

  """
  @spec currency_history_for_locale(LanguageTag.t) :: map() | nil
  def currency_history_for_locale(%LanguageTag{} = locale) do
    locale
    |> Cldr.Locale.territory_from_locale()
    |> territory_currencies()
  end

  @spec currency_history_for_locale(Locale.locale_name, Cldr.backend) ::
    map() | {:error, {module(), String.t}}
  def currency_history_for_locale(locale_name, backend) when is_binary(locale_name) do
    with {:ok, locale} <- Cldr.validate_locale(locale_name, backend) do
      currency_history_for_locale(locale)
    end
  end

  @doc """
  Returns the current currency for a given locale.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  ## Example

      iex> Cldr.Currency.current_currency_for_locale "en", MyApp.Cldr
      :USD

      iex> Cldr.Currency.current_currency_for_locale "en-AU", MyApp.Cldr
      :AUD

  """
  @spec current_currency_for_locale(LanguageTag.t()) :: any()

  def current_currency_for_locale(%LanguageTag{} = locale) do
    with {:ok, history} <- currency_history_for_locale(locale) do
      history
      |> Enum.find(fn {_currency, dates} -> Map.has_key?(dates, :to) && is_nil(dates.to) end)
      |> elem(0)
    end
  end

  @spec current_currency_for_locale(Cldr.Locale.locale_name(), Cldr.backend()) ::
    code() | nil | {:error, {module(), String.t()}}

  def current_currency_for_locale(locale_name, backend) when is_binary(locale_name) do
    with {:ok, locale} <- Cldr.validate_locale(locale_name, backend) do
      current_currency_for_locale(locale)
    end
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
  @spec known_currency?(code(), list(t())) :: boolean

  def known_currency?(currency_code, custom_currencies \\ []) do
    with {:ok, currency_code} <- Cldr.validate_currency(currency_code),
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

      iex> Cldr.Currency.currency_for_code("AUD", MyApp.Cldr)
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

      iex> Cldr.Currency.currency_for_code("THB", MyApp.Cldr)
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
          {:ok, t} | {:error, {module(), String.t()}}

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

    {:ok, meta} =
      new(code,
        name: string_code,
        symbol: string_code,
        narrow_symbol: string_code,
        count: %{other: string_code}
      )

    meta
  end

  defp get_currency_metadata(_code, meta) do
    meta
  end

  @doc """
  Returns a map of the metadata for all currencies for
  a given locale.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  * `currency_status` is `:all`, `:current`, `:historic`,
    `unannotated` or `:tender`; or a list of one or more status.
    The default is `:all`. See `Cldr.Currency.currency_filter/2`.

  ## Returns

  * `{:ok, currency_map}` or

  * `{:error, {exception, reason}}`

  ## Example

    => Cldr.Currency.currencies_for_locale "en", MyApp.Cldr
    {:ok,
     %{
       FJD: %Cldr.Currency{
         cash_digits: 2,
         cash_rounding: 0,
         code: "FJD",
         count: %{one: "Fijian dollar", other: "Fijian dollars"},
         digits: 2,
         from: nil,
         iso_digits: 2,
         name: "Fijian Dollar",
         narrow_symbol: "$",
         rounding: 0,
         symbol: "FJD",
         tender: true,
         to: nil
       },
       SUR: %Cldr.Currency{
         cash_digits: 2,
         cash_rounding: 0,
         code: "SUR",
         count: %{one: "Soviet rouble", other: "Soviet roubles"},
         digits: 2,
         from: nil,
         iso_digits: nil,
         name: "Soviet Rouble",
         narrow_symbol: nil,
         rounding: 0,
         symbol: "SUR",
         tender: true,
         to: nil
       },
       ...
      }}

  """
  @spec currencies_for_locale(Locale.locale_name() | LanguageTag.t(), Cldr.backend(), currency_status) ::
          {:ok, map()} | {:error, {module(), String.t()}}

  def currencies_for_locale(locale, backend, currency_status \\ :all) do
    Module.concat(backend, Currency).currencies_for_locale(locale, currency_status)
  end

  @doc """
  Returns a map of the metadata for all currencies for
  a given locale and raises on error.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  * `currency_status` is `:all`, `:current`, `:historic`,
    `unannotated` or `:tender`; or a list of one or more status.
    The default is `:all`. See `Cldr.Currency.currency_filter/2`.

  ## Returns

  * `{:ok, currency_map}` or

  * raises an exception

  ## Example

    => MyApp.Cldr.Currency.currencies_for_locale! "en"
    %{
      FJD: %Cldr.Currency{
        cash_digits: 2,
        cash_rounding: 0,
        code: "FJD",
        count: %{one: "Fijian dollar", other: "Fijian dollars"},
        digits: 2,
        from: nil,
        iso_digits: 2,
        name: "Fijian Dollar",
        narrow_symbol: "$",
        rounding: 0,
        symbol: "FJD",
        tender: true,
        to: nil
      },
      SUR: %Cldr.Currency{
        cash_digits: 2,
        cash_rounding: 0,
        code: "SUR",
        count: %{one: "Soviet rouble", other: "Soviet roubles"},
        digits: 2,
        from: nil,
        iso_digits: nil,
        name: "Soviet Rouble",
        narrow_symbol: nil,
        rounding: 0,
        symbol: "SUR",
        tender: true,
        to: nil
      },
      ...
     }

  """
  @spec currencies_for_locale!(Locale.locale_name() | LanguageTag.t(), Cldr.backend(), currency_status) ::
          map() | no_return()

  def currencies_for_locale!(locale, backend, currency_status \\ :all) do
    Module.concat(backend, Currency).currencies_for_locale!(locale, currency_status)
  end

  @doc """
  Returns a map that matches a currency string to a
  currency code.

  A currency string is a localised name or symbol
  representing a currency in a locale-specific manner.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`.

  * `currency_status` is `:all`, `:current`, `:historic`,
    `unannotated` or `:tender`; or a list of one or more status.
    The default is `:all`. See `Cldr.Currency.currency_filter/2`.

  ## Returns

  * `{:ok, currency_string_map}` or

  * `{:error, {exception, reason}}`

  ## Example

      => Cldr.Currency.currency_strings "en", MyApp.Cldr
      {:ok,
       %{
         "mexican silver pesos" => :MXP,
         "sudanese dinar" => :SDD,
         "bad" => :BAD,
         "rsd" => :RSD,
         "swazi lilangeni" => :SZL,
         "zairean new zaire" => :ZRN,
         "guyanaese dollars" => :GYD,
         "equatorial guinean ekwele" => :GQE,
         ...
      }}

      # Currencies match all currency status'
      => Cldr.Currency.currency_strings "en", MyApp.Cldr, [:tender, :current, :unannotated]
      {:ok,
       %{
         "rsd" => :RSD,
         "swazi lilangeni" => :SZL,
         "guyanaese dollars" => :GYD,
         "syrian pound" => :SYP,
         "scr" => :SCR,
         "bangladeshi takas" => :BDT,
         "netherlands antillean guilders" => :ANG,
         "pen" => :PEN,
         ...
      }}

  """
  @spec currency_strings(Cldr.LanguageTag.t() | Cldr.Locale.locale_name(), Cldr.Currency.currency_status()) ::
          {:ok, map()} | {:error, {module(), String.t()}}

  def currency_strings(locale, backend, currency_status \\ :all) do
    Module.concat(backend, Currency).currency_strings(locale, currency_status)
  end

  @doc """
  Returns a map that matches a currency string to a
  currency code or raises an exception.

  A currency string is a localised name or symbol
  representing a currency in a locale-specific manner.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`.

  * `currency_status` is `:all`, `:current`, `:historic`,
    `unannotated` or `:tender`; or a list of one or more status.
    The default is `:all`. See `Cldr.Currency.currency_filter/2`.

  ## Returns

  * `{:ok, currency_string_map}` or

  * raises an exception

  ## Example

      => Cldr.Currency.currency_strings! "en", MyApp.Cldr
      %{
        "mexican silver pesos" => :MXP,
        "sudanese dinar" => :SDD,
        "bad" => :BAD,
        "rsd" => :RSD,
        "swazi lilangeni" => :SZL,
        "zairean new zaire" => :ZRN,
        "guyanaese dollars" => :GYD,
        "equatorial guinean ekwele" => :GQE,
        ...
      }

  """
  @spec currency_strings!(Cldr.LanguageTag.t() | Cldr.Locale.locale_name(), Cldr.Currency.currency_status()) ::
          map() | no_return

  def currency_strings!(locale, backend, currency_status \\ :all) do
    case Module.concat(backend, Currency).currency_strings(locale, currency_status) do
      {:ok, currency_strings} -> currency_strings
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  @doc """
  Returns the strings associated with a currency
  in a given locale.

  ## Arguments

  * `currency` is an ISO4217 currency code

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`.

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  ## Returns

  * A list of strings or

  * `{:error, {exception, reason}}`

  ## Example

      iex> Cldr.Currency.strings_for_currency :AUD, "en", MyApp.Cldr
      ["a$", "australian dollars", "aud", "australian dollar"]

      iex> Cldr.Currency.strings_for_currency :AUD, "de", MyApp.Cldr
      ["australische dollar", "australischer dollar", "au$", "aud"]

      iex> Cldr.Currency.strings_for_currency :AUD, "zh", MyApp.Cldr
      ["澳大利亚元", "au$", "aud"]

  """
  def strings_for_currency(currency, locale, backend) do
    module = Module.concat(backend, Currency)

    with {:ok, currency_strings} <- module.currency_strings(locale),
         {:ok, currency} <- Cldr.validate_currency(currency) do
      Enum.filter(currency_strings, fn {_k, v} -> v == currency end)
      |> Enum.map(fn {k, _v} -> k end)
    end
  end

  @doc """
  Return only those currencies meeting the
  filter criteria.

  ## Arguments

  * `currency` is a `Cldr.Currency.t`, a list of `Cldr.Currency.t` or a
    map where the values of each item is a `Cldr.Currency.t`

  * `currency_status` is `:all`, `:current`, `:historic`, `:tender`
    `unannotated` or a list of one or more status. The default is `:all`

  ## Currency Status

  A currency may be in current use, of historic interest only. It
  may or may not be legal tender. And it may mostly be used as a financial
  instrument.  To help return the most useful currencies the
  currency status code acts as follows:

  * `:all`, the default, returns all currencies

  * `:current` returns those currencies that have a `:to`
    date of nil and which also is a known ISO4217 currency

  * `:historic` is the opposite of `:current`

  * `:tender` is a currency that is legal tender

  * `:unannotated` is a currency that doesn't have
    "(some string)" in its name.  These are usually
    financial instruments.

  """
  @spec currency_filter(
          Cldr.Currency.t() | [Cldr.Currency.t()] | map(),
          Cldr.Currency.currency_status()
        ) :: boolean

  def currency_filter(currency, currency_status)

  def currency_filter(%Cldr.Currency{} = _currency, :all) do
    true
  end

  def currency_filter(%Cldr.Currency{} = currency, :current) do
    !is_nil(currency.iso_digits) && is_nil(currency.to)
  end

  def currency_filter(%Cldr.Currency{} = currency, :historic) do
    is_nil(currency.iso_digits) ||
      (is_integer(currency.to) && currency.to < Date.utc_today().year)
  end

  def currency_filter(%Cldr.Currency{} = currency, :tender) do
    currency.tender
  end

  def currency_filter(%Cldr.Currency{} = currency, :unannotated) do
    !String.contains?(currency.name, "(")
  end

  def currency_filter(%Cldr.Currency{} = currency, status) when is_list(status) do
    Enum.all?(status, fn s -> currency_filter(currency, s) end)
  end

  def currency_filter(currencies, :all) when is_map(currencies) do
    currencies
  end

  def currency_filter(currencies, currency_status) when is_map(currencies) do
    Enum.filter(currencies, fn {_m, c} -> currency_filter(c, currency_status) end)
    |> Map.new()
  end

  def currency_filter(currencies, currency_status) when is_list(currencies) do
    Enum.filter(currencies, &currency_filter(&1, currency_status))
  end

  def historic?(%Cldr.Currency{} = currency) do
    currency_filter(currency, :historic)
  end

  def tender?(%Cldr.Currency{} = currency) do
    currency_filter(currency, :tender)
  end

  def current?(%Cldr.Currency{} = currency) do
    currency_filter(currency, :current)
  end

  def unannotated?(%Cldr.Currency{} = currency) do
    currency_filter(currency, :unannotated)
  end

  # Sort the list by string. If the string is the same
  # then sort historic currencies after the current one
  @doc false
  def string_comparator({k, v1}, {k, v2}, currencies) do
    cond do
      historic?(currencies[v1]) -> false
      historic?(currencies[v2]) -> true
      true -> raise "String #{inspect k} has two current currencies of #{inspect v1} and " <>
        "#{inspect v2}"
    end
  end

  def string_comparator({k1, _v1}, {k2, _v2}, _currencies) do
    k1 < k2
  end

  # Its possible that more than one currency will have a string
  # in common with another currency. One example is `:AFA` and
  # `:AFN`.  As in this csae, its most common when a country
  # changes to a new currency with the same name.

  # The strategy is to remove the duplicate string from the
  # currency that is historic.
  @doc false
  def remove_duplicate_strings(strings, currencies) do
    strings
    |> Enum.sort(fn a, b -> string_comparator(a, b, currencies) end)
    |> remove_duplicates(currencies)
  end

  defp remove_duplicates([{_, _}] = currency, _currencies) do
    currency
  end

  # Same string, different code -> omit the 2nd one since
  # we sort historic currencies after the current ones
  defp remove_duplicates([{c1, code1} | [{c1, _code2} | rest]], currencies) do
    remove_duplicates([{c1, code1} | rest], currencies)
  end

  # Not a duplicate, process the rest of the list
  defp remove_duplicates([{c1, code1} | rest], currencies) do
    [{c1, code1} | remove_duplicates(rest, currencies)]
  end

  @doc false
  def invert_currency_strings(currency_strings) do
    Enum.reduce(currency_strings, [], fn {code, strings}, acc ->
      [Enum.map(strings, fn string -> {string, code} end) | acc]
    end)
    |> List.flatten
  end
end
