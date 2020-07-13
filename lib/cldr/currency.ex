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

  @type code :: atom()

  @type currency_status :: :all | :current | :historic | :tender | :unannotated | :private

  @type filter :: list(currency_status | code) | currency_status | code

  @type t :: %__MODULE__{
          code: code,
          alt_code: code,
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
            alt_code: nil,
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

  # Starts the supervisor for the private use
  # currencies, delegated to Eternal which
  # keeps :ets tables alive as much as is
  # possible

  @doc false
  def start_link(_init_arg) do
    start_link()
  end

  @doc false
  def start_link do
    Eternal.start_link(__MODULE__, [ :set, { :read_concurrency, true }], [ quiet: true ])
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Returns a `Currency` struct created from the arguments.

  ## Arguments

  * `currency` is a custom currency code of a format defined in ISO4217

  * `options` is a map of options representing the optional elements of
    the `t:Cldr.Currency.t` struct

  ## Options

  * `:name` is the name of the currenct. Required.
  * `:digits` is the precision of the currency. Required.
  * `:symbol` is the currency symbol. Optional.
  * `:narrow_symbol` is an alternative narrow symbol. Optional.
  * `:round_nearest` is the rounding precision such as `0.05`.
    Optional.
  * `:alt_code` is an alternative currency code for application use.
  * `:cash_digits` is the precision of the currency when used as cash.
    Optional.
  * `:cash_round_nearest` is the rounding precision when used as cash
    such as `0.05`. Optional.

  ## Returns

  * `{:ok, Cldr.Currency.t}` or

  * `{:error, {exception, message}}`

  ## Example

      iex> Cldr.Currency.new(:XAA, name: "XAA currency", digits: 0)
      {:ok,
       %Cldr.Currency{
         alt_code: :XAA,
         cash_digits: 0,
         cash_rounding: nil,
         code: :XAA,
         count: %{other: "XAA currency"},
         digits: 0,
         from: nil,
         iso_digits: 0,
         name: "XAA currency",
         narrow_symbol: nil,
         rounding: 0,
         symbol: "XAA",
         tender: false,
         to: nil
       }}

      iex> Cldr.Currency.new(:XBC)
      {:error, {Cldr.CurrencyAlreadyDefined, "Currency :XBC is already defined."}}

      iex> Cldr.Currency.new(:ZAA, name: "Invalid Custom Name", digits: 0)
      {:error, {Cldr.UnknownCurrencyError, "The currency :ZAA is invalid"}}

  """
  @spec new(binary | atom, map | list) :: {:ok, t} | {:error, {module(), String.t}}
  def new(currency, options \\ [])

  def new(currency, options) when is_list(options) do
    with {:ok, currency_code} <- Cldr.validate_currency(currency),
         {:ok, currency_code} <- validate_new_currency(currency_code),
         {:ok, options} <- validate_options(currency_code, options) do
      currency = struct(@struct, [{:code, currency_code} | options])
      store_currency(currency)
    end
  end

  defp validate_options(code, options) do
    with {:ok, options} <- assert_options(options, [:name, :digits]) do
      options = [
        code: code,
        alt_code: options[:alt_code] || code,
        name: options[:name],
        symbol: options[:symbol] || to_string(code),
        narrow_symbol: options[:narrow_symbol] || options[:symbol],
        digits: options[:digits],
        rounding: options[:round_nearest] || 0,
        cash_digits: options[:cash_digits] || options[:digits],
        cash_rounding: options[:cash_round_nearest] || options[:round_nearest],
        iso_digits: options[:digits],
        tender: options[:tender] || false,
        count: options[:count] || %{other: options[:name]}
      ]

      {:ok, options}
    end
  end

  defp assert_options(options, keys) do
    if Enum.all?(keys, &options[&1]) do
      {:ok, options}
    else
      {:error, "Required option(s) missing. Required options are #{inspect keys}"}
    end
  end
  @doc """
  Determines is a new currency is already
  defined.

  ## Example

      iex> Cldr.Currency.validate_new_currency :XAC
      {:ok, :XAC}

      iex> Cldr.Currency.validate_new_currency :USD
      {:error, {Cldr.CurrencyAlreadyDefined, "Currency :USD is already defined."}}

  """
  @spec validate_new_currency(code) :: {:ok, code} | {:error, {module, String.t}}
  def validate_new_currency(code) do
    if code in known_currency_codes() do
      {:error, {Cldr.CurrencyAlreadyDefined, currency_already_defined_error(code)}}
    else
      {:ok, code}
    end
  end

  def store_currency(%Cldr.Currency{code: code} = currency) do
    :ets.insert_new(__MODULE__, {code, currency})
    {:ok, currency}
  rescue ArgumentError ->
    {:error, {Cldr.CurrencyNotSavedError, currency_not_saved_error(code)}}
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
    default is `<backend>.get_locale/1`

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
    locale = Keyword.get_lazy(options, :locale, &backend.get_locale/0)
    options = Keyword.put(options, :locale, locale)

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

      iex> Cldr.Currency.known_currency_codes |> Enum.count
      303

  """
  @spec known_currency_codes() :: list(atom)
  def known_currency_codes do
    Cldr.known_currencies() ++ private_currency_codes()
  end

  @deprecated "Use known_currency_codes/0"
  defdelegate known_currencies, to: __MODULE__, as: :known_currency_codes

  @doc """
  Returns a boolean indicating if the supplied currency code is known.

  ## Arguments

  * `currency_code` is a `binary` or `atom` representing an ISO4217
    currency code

  ## Returns

  * `true` or `false`

  ## Examples

      iex> Cldr.Currency.known_currency_code? "AUD"
      true

      iex> Cldr.Currency.known_currency_code? "GGG"
      false

      iex> Cldr.Currency.known_currency_code? :XCV
      false

  """
  @spec known_currency_code?(code()) :: boolean
  def known_currency_code?(currency_code) do
    with {:ok, currency_code} <- Cldr.validate_currency(currency_code) do
      currency_code in known_currency_codes()
    else
      _other -> false
    end
  end

  @deprecated "Use known_currency_code?/0"
  defdelegate known_currency?(currency), to: __MODULE__, as: :known_currency_code?

  @doc """
  Returns a 2-tuple indicating if the supplied currency code is known.

  ## Arguments

  * `currency_code` is a `binary` or `atom` representing an ISO4217
    currency code

  ## Returns

  * `{:ok, currency_code}` or

  * `{:error, {exception, reason}}`

  ## Examples

      iex> Cldr.Currency.known_currency_code "AUD"
      {:ok, :AUD}

      iex> Cldr.Currency.known_currency_code "GGG"
      {:error, {Cldr.UnknownCurrencyError, "The currency \\"GGG\\" is invalid"}}

  """
  @spec known_currency_code(code()) :: {:ok, code} | {:error, {module, String.t}}
  def known_currency_code(currency_code) do
    with {:ok, currency_code} <- Cldr.validate_currency(currency_code) do
      if currency_code in known_currency_codes() do
        {:ok, currency_code}
      else
        {:error, {Cldr.UnknownCurrencyError, Cldr.unknown_currency_error(currency_code)}}
      end
    end
  end

  @doc """
  Returns a list of all private currency codes.

  """
  @spec private_currency_codes() :: list(atom)
  def private_currency_codes do
    Map.keys(private_currencies())
  end

  @doc """
  Returns a map of private currencies.

  These comprise all currencies created with
  `Cldr.Currency.new/2`.

  """
  @spec private_currencies :: %{code => t}
  def private_currencies do
    __MODULE__
    |> :ets.tab2list
    |> Map.new
  rescue ArgumentError ->
    %{}
  end

  @doc """
  Returns the effective currency for a given locale

  ## Arguments

  * `locale` is a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  ## Returns

  * A ISO 4217 currency code as an upcased atom

  ## Examples

      iex> {:ok, locale} = Cldr.validate_locale "en", MyApp.Cldr
      iex> Cldr.Currency.currency_from_locale locale
      :USD

      iex> {:ok, locale} = Cldr.validate_locale "en-AU", MyApp.Cldr
      iex> Cldr.Currency.currency_from_locale locale
      :AUD

      iex> Cldr.Currency.currency_from_locale "en-GB"
      :GBP

  """
  def currency_from_locale(%LanguageTag{locale: %{currency: nil}} = locale) do
    current_currency_from_locale(locale)
  end

  def currency_from_locale(%LanguageTag{locale: %{currency: currency}}) do
    currency
  end

  def currency_from_locale(%LanguageTag{} = locale) do
    current_currency_from_locale(locale)
  end

  @doc """
  Returns the effective currency for a given locale

  ## Arguments

  * `locale` is any valid locale name returned by
    `Cldr.known_locale_names/1`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module. The default is `Cldr.default_backend/0`

  ## Returns

  * A ISO 4217 currency code as an upcased atom

  ## Examples

      iex> Cldr.Currency.currency_from_locale "fr-CH", MyApp.Cldr
      :CHF

      iex> Cldr.Currency.currency_from_locale "fr-CH-u-cu-INR", MyApp.Cldr
      :INR

  """
  def currency_from_locale(locale, backend \\ Cldr.default_backend()) when is_binary(locale) do
    with {:ok, locale} <- Cldr.validate_locale(locale, backend) do
      currency_from_locale(locale)
    end
  end

  @doc """
  Returns the effective currency format for a given locale

  ## Arguments

  * `locale` a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  ## Returns

  * Either `:accounting` or `:currency`

  ## Examples

      iex> {:ok, locale} = Cldr.validate_locale "en", MyApp.Cldr
      iex> Cldr.Currency.currency_format_from_locale locale
      :currency

      iex> {:ok, locale} = Cldr.validate_locale "en-AU-u-cu-eur", MyApp.Cldr
      iex> Cldr.Currency.currency_format_from_locale locale
      :currency

      iex> {:ok, locale} = Cldr.validate_locale "en-AU-u-cu-eur-cf-account", MyApp.Cldr
      iex> Cldr.Currency.currency_format_from_locale locale
      :accounting

  """
  def currency_format_from_locale(%LanguageTag{locale: %{currency_format: nil}}) do
    :currency
  end

  def currency_format_from_locale(%LanguageTag{locale: %{currency_format: currency_format}}) do
    currency_format
  end

  def currency_format_from_locale(%LanguageTag{}) do
    :currency
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
  @spec currency_history_for_locale(LanguageTag.t) ::
    {:ok, map()} | {:error, {atom, binary}}

  def currency_history_for_locale(%LanguageTag{} = locale) do
    locale
    |> Cldr.Locale.territory_from_locale()
    |> territory_currencies()
  end

  @spec currency_history_for_locale(Locale.locale_name, Cldr.backend) ::
    {:ok, map()} | {:error, {module(), String.t}}

  def currency_history_for_locale(locale_name, backend) when is_binary(locale_name) do
    with {:ok, locale} <- Cldr.validate_locale(locale_name, backend) do
      currency_history_for_locale(locale)
    end
  end

  @doc """
  Returns the current currency from a given locale.

  This function does not consider the `U` extenion
  parameters `cu` or `rg`. It is recommended to us
  `Cldr.Currency.currency_from_locale/1` in most
  circumstances.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

  * `backend` is any module that includes `use Cldr` and therefore
    is a `Cldr` backend module

  ## Examples

      iex> Cldr.Currency.current_currency_from_locale "en", MyApp.Cldr
      :USD

      iex> Cldr.Currency.current_currency_from_locale "en-AU", MyApp.Cldr
      :AUD

  """
  @spec current_currency_from_locale(LanguageTag.t()) :: any()

  def current_currency_from_locale(%LanguageTag{} = locale) do
    locale
    |> Cldr.Locale.territory_from_locale()
    |> current_currency_for_territory()
  end

  @spec current_currency_from_locale(Cldr.Locale.locale_name(), Cldr.backend()) ::
    code() | nil | {:error, {module(), String.t()}}

  def current_currency_from_locale(locale_name, backend) when is_binary(locale_name) do
    with {:ok, locale} <- Cldr.validate_locale(locale_name, backend) do
      current_currency_from_locale(locale)
    end
  end

  @doc """
  Returns the current currency for a given territory.

  ## Arguments

  * `territory` is any valid territory name returned by
    `Cldr.known_territories/0`

  ## Examples

      iex> Cldr.Currency.current_currency_for_territory :US
      :USD

      iex> Cldr.Currency.current_currency_for_territory :AU
      :AUD

  """
  @spec current_currency_for_territory(Cldr.territory()) ::
    code() | nil | {:error, {module(), String.t()}}

  def current_currency_for_territory(territory) do
    with {:ok, territory} <- Cldr.validate_territory(territory),
         {:ok, history} <- territory_currencies(territory) do

      history
      |> Enum.find(fn {_currency, dates} -> Map.has_key?(dates, :to) && is_nil(dates.to) end)
      |> elem(0)
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
    {locale, backend} = Cldr.locale_and_backend_from(options[:locale], backend)

    with {:ok, code} <- known_currency_code(currency_code),
         {:ok, locale} <- Cldr.validate_locale(locale, backend),
         {:ok, currencies} <- currencies_for_locale(locale, backend) do

      {:ok, Map.get_lazy(currencies, code, fn -> Map.get(private_currencies(), code) end)}
    end
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
  @spec currencies_for_locale(Locale.locale_name() | LanguageTag.t(), Cldr.backend(),
          only :: filter(), except :: filter()) ::
          {:ok, map()} | {:error, {module(), String.t()}}

  def currencies_for_locale(locale, backend, only \\ :all, except \\ nil) do
    Module.concat(backend, Currency).currencies_for_locale(locale, only, except)
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

    #=> MyApp.Cldr.Currency.currencies_for_locale! "en"
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
  @spec currencies_for_locale!(Locale.locale_name() | LanguageTag.t(),
          Cldr.backend(),
          only :: filter(),
          except :: filter()) ::
          map() | no_return()

  def currencies_for_locale!(locale, backend, only \\ :all, except \\ nil) do
    Module.concat(backend, Currency).currencies_for_locale!(locale, only, except)
  end

  @doc """
  Returns a map that matches a currency string to a
  currency code.

  A currency string is a localised name or symbol
  representing a currency in a locale-specific manner.

  ## Arguments

  * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
    or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`.

  * `:only` is `:all`, `:current`, `:historic`,
    `unannotated` or `:tender`; or a list of one or more status
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
  @spec currency_strings(Cldr.LanguageTag.t() | Cldr.Locale.locale_name(),
          only :: filter(), except :: filter()) ::
          {:ok, map()} | {:error, {module(), String.t()}}

  def currency_strings(locale, backend, only \\ :all, except \\ nil) do
    Module.concat(backend, Currency).currency_strings(locale, only, except)
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
  @spec currency_strings!(Cldr.LanguageTag.t() | Cldr.Locale.locale_name(),
          only :: filter(), except :: filter()) ::
          map() | no_return

  def currency_strings!(locale, backend, only \\ :all, except \\ nil) do
    case Module.concat(backend, Currency).currency_strings(locale, only, except) do
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

  * `only` is `:all`, `:current`, `:historic`, `:tender`
    `unannotated` or a list of one or more status or currency codes.
    The default is `:all`

  * `except` is `:current`, `:historic`, `:tender`
    `unannotated` or a list of one or more status or currency codes.
    The default is `nil`

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
        ) :: list(Cldr.Currency.t)

  def currency_filter(currencies, only \\ :all, except \\ nil)

  def currency_filter(currencies, only, except) when not is_list(only) do
    currency_filter(currencies, [only], except)
  end

  def currency_filter(currencies, only, except) when not is_list(except) do
    currency_filter(currencies, only, [except])
  end

  def currency_filter(%Cldr.Currency{} = currency, only, except)  do
    currency_filter([currency], only, except)
  end

  def currency_filter(currencies, only, except) when is_map(currencies) do
    currencies
    |> Map.values
    |> currency_filter(only, except)
    |> Map.new(fn currency -> {String.to_atom(currency.code), currency} end)
  end

  def currency_filter(currencies, [:all], [nil])  do
    currencies
  end

  def currency_filter(currencies, only, except)  do
    expand_filter(currencies, :only, only) -- expand_filter(currencies, :except, except)
  end

  def expand_filter(currencies, :only, [:all]) do
    currencies
  end

  def expand_filter(_currencies, :except, [nil]) do
    []
  end

  def expand_filter(currencies, _, filter_list) do
    Enum.flat_map(filter_list, fn filter ->
      case filter do
        :historic ->
          Enum.filter(currencies, &historic?/1)
        :tender ->
          Enum.filter(currencies, &tender?/1)
        :current ->
          Enum.filter(currencies, &current?/1)
        :annotated ->
          Enum.filter(currencies, &annotated?/1)
        :unannotated ->
          Enum.filter(currencies, &unannotated?/1)
        :private ->
          private_currencies()
        code when is_binary(code) ->
          Enum.filter(currencies, fn currency ->
            currency.code == code
          end)
        code when is_atom(code) ->
          code = to_string(code)
          Enum.filter(currencies, fn currency ->
            currency.code == code
          end)
      end
    end)
    |> Enum.uniq
  end

  def historic?(%Cldr.Currency{} = currency) do
    is_nil(currency.iso_digits) ||
    (is_integer(currency.to) && currency.to < Date.utc_today().year)
  end

  def tender?(%Cldr.Currency{} = currency) do
    !!currency.tender
  end

  def current?(%Cldr.Currency{} = currency) do
    !is_nil(currency.iso_digits) && is_nil(currency.to)
  end

  def annotated?(%Cldr.Currency{} = currency) do
    String.contains?(currency.name, "(")
  end

  def unannotated?(%Cldr.Currency{} = currency) do
    !String.contains?(currency.name, "(")
  end

  # Sort the list by string. If the string is the same
  # then sort historic currencies after the current one
  @doc false
  def string_comparator({k, v1}, {k, v2}, currencies) do
    cond do
      historic?(currencies[v1]) -> false
      historic?(currencies[v2]) -> true
      true -> raise "String #{inspect k} has two current currencies of #{inspect v1} and " <>
        "#{inspect v2}."
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

  defp currency_already_defined_error(code) do
    "Currency #{inspect(code)} is already defined."
  end

  defp currency_not_saved_error(code) do
    """
    The currency #{inspect code} could not be defined.

    This is probably because the table is not defined
    in which the new currency information is saved.

    Please ensure you have the `Cldr.Currency` supervisor
    defined as a child in your application supervisor tree.
    """
  end
end
