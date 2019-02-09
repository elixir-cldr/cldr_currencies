defmodule Cldr.Currency.Backend do
  def define_currency_module(config) do
    module = inspect(__MODULE__)
    backend = config.backend
    config = Macro.escape(config)

    quote location: :keep, bind_quoted: [module: module, backend: backend, config: config] do
      defmodule Currency do
        @doc """
        Returns a `Currency` struct created from the arguments.

        ## Arguments

        * `currency` is a custom currency code of a format defined in ISO4217

        * `options` is a map of options representing the optional elements of
          the `%Cldr.Currency{}` struct

        ## Returns

        * `{:ok, Cldr.Currency.t}` or

        * `{:error, {exception, message}}`

        ## Example

            iex> #{inspect(__MODULE__)}.new(:XAA)
            {:ok,
             %Cldr.Currency{cash_digits: 0, cash_rounding: 0, code: :XAA, count: nil,
              digits: 0, name: "", narrow_symbol: nil, rounding: 0, symbol: "",
              tender: false}}

            iex> #{inspect(__MODULE__)}.new(:ZAA, name: "Invalid Custom Name")
            {:error, {Cldr.UnknownCurrencyError, "The currency :ZAA is invalid"}}

            iex> #{inspect(__MODULE__)}.new("xaa", name: "Custom Name")
            {:ok,
             %Cldr.Currency{cash_digits: 0, cash_rounding: 0, code: :XAA, count: nil,
              digits: 0, name: "Custom Name", narrow_symbol: nil, rounding: 0, symbol: "",
              tender: false}}

            iex> #{inspect(__MODULE__)}.new(:XAA, name: "Custom Name")
            {:ok,
             %Cldr.Currency{cash_digits: 0, cash_rounding: 0, code: :XAA, count: nil,
              digits: 0, name: "Custom Name", narrow_symbol: nil, rounding: 0, symbol: "",
              tender: false}}

            iex> #{inspect(__MODULE__)}.new(:XBC)
            {:error, {Cldr.CurrencyAlreadyDefined, "Currency :XBC is already defined"}}

        """
        alias Cldr.Locale

        @spec new(binary | atom, map | list) :: Cldr.Currency.t() | {:error, binary}
        def new(currency, options \\ [])

        def new(currency, options) do
          Cldr.Currency.new(currency, options)
        end

        @doc """
        Returns the appropriate currency display name for the `currency`, based
        on the plural rules in effect for the `locale`.

        ## Arguments

        * `number` is an integer, float or `Decimal`

        * `currency` is any currency returned by `Cldr.Currency.known_currencies/0`

        * `options` is a keyword list of options

        ## Options

        * `:locale` is any locale returned by `Cldr.Locale.new!/2`. The
        default is `Cldr.get_current_locale/1`

        ## Returns

        * `{:ok, plural_string}` or

        * `{:error, {exception, message}}`

        ## Examples

            iex> #{inspect(__MODULE__)}.pluralize 1, :USD
            {:ok, "US dollar"}

            iex> #{inspect(__MODULE__)}.pluralize 3, :USD
            {:ok, "US dollars"}

            iex> #{inspect(__MODULE__)}.pluralize 12, :USD, locale: "zh"
            {:ok, "美元"}

            iex> #{inspect(__MODULE__)}.pluralize 12, :USD, locale: "fr"
            {:ok, "dollars des États-Unis"}

            iex> #{inspect(__MODULE__)}.pluralize 1, :USD, locale: "fr"
            {:ok, "dollar des États-Unis"}

        """
        @spec pluralize(pos_integer, atom, Keyword.t()) ::
                {:ok, String.t()} | {:error, {Exception.t(), String.t()}}
        def pluralize(number, currency, options \\ []) do
          Cldr.Currency.pluralize(number, currency, unquote(backend), options)
        end

        @doc """
        Returns a list of all known currency codes.

        ## Example

            iex> #{inspect(__MODULE__)}.known_currencies |> Enum.count
            303

        """
        @spec known_currencies() :: list(atom)
        def known_currencies do
          Cldr.Currency.known_currencies
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

            iex> #{inspect(__MODULE__)}.known_currency? "AUD"
            true

            iex> #{inspect(__MODULE__)}.known_currency? "GGG"
            false

            iex> #{inspect(__MODULE__)}.known_currency? :XCV
            false

            iex> #{inspect(__MODULE__)}.known_currency? :XCV, [%Cldr.Currency{code: :XCV}]
            true

        """
        @spec known_currency?(Cldr.Currency.code, [Cldr.Currency.t(), ...]) :: boolean
        def known_currency?(currency_code, custom_currencies \\ []) do
          Cldr.Currency.known_currency?(currency_code, custom_currencies)
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

            iex> #{inspect(__MODULE__)}.make_currency_code("xzz")
            {:ok, :XZZ}

            iex> #{inspect(__MODULE__)}.make_currency_code("aaa")
            {:error, {Cldr.CurrencyCodeInvalid,
             "Invalid currency code \\"AAA\\".  Currency codes must start with 'X' followed by 2 alphabetic characters only."}}

        """
        @valid_currency_code Regex.compile!("^X[A-Z]{2}$")
        @spec make_currency_code(binary | atom) :: {:ok, atom} | {:error, binary}
        def make_currency_code(code) do
          Cldr.Currency.make_currency_code(code)
        end

        @doc """
        Returns the currency metadata for the requested currency code.

        ## Arguments

        * `currency_code` is a `binary` or `atom` representation of an
          ISO 4217 currency code.

        ## Examples

            iex> #{inspect(__MODULE__)}.currency_for_code("AUD")
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

            iex> #{inspect(__MODULE__)}.currency_for_code("THB")
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
        @spec currency_for_code(Cldr.Currency.code, LanguageTag.t()) ::
                {:ok, Cldr.Currency.t()} | {:error, {Exception.t(), String.t()}}
        def currency_for_code(currency_code, options \\ [locale: unquote(backend).default_locale()]) do
          Cldr.Currency.currency_for_code(currency_code, unquote(backend), options)
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

        ## Arguments

        * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
          or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

        """
        @spec currencies_for_locale(Locale.name() | LanguageTag.t()) ::
                {:ok, Map.t()} | {:error, {Exception.t(), String.t()}}
        def currencies_for_locale(locale)

        convert_or_nilify = fn
          "" -> nil
          other -> String.to_integer(other)
        end

        @reg Regex.compile! "(?<currency>[^\\(0-9]+)(\\((?<from>[0-9]{4}))?([–-](?<to>[0-9]{4}))?"
        for locale_name <- Cldr.Config.known_locale_names(config) do
          currencies =
            locale_name
            |> Cldr.Config.get_locale(config)
            |> Map.get(:currencies)
            |> Enum.map(fn {k, v} ->
              name_and_range = Regex.named_captures(@reg, Map.get(v, :name))
              name = Map.get(name_and_range, "currency") |> String.trim
              from = convert_or_nilify.(Map.get(name_and_range, "from"))
              to = convert_or_nilify.(Map.get(name_and_range, "to"))
              count = Enum.map(Map.get(v, :count), fn {k, v} ->
                {k, String.replace(v, ~r/ \(.*/, "")}
              end)
              |> Map.new

              currency =
                v
                |> Map.put(:name, name)
                |> Map.put(:from, from)
                |> Map.put(:to, to)
                |> Map.put(:count, count)

              {k, struct(Cldr.Currency, currency)}
            end)
            |> Enum.into(%{})

          def currencies_for_locale(%LanguageTag{cldr_locale_name: unquote(locale_name)}) do
            {:ok, unquote(Macro.escape(currencies))}
          end
        end

        def currencies_for_locale(locale_name) when is_binary(locale_name) do
          with {:ok, locale} <- Cldr.validate_locale(locale_name, unquote(backend)) do
            currencies_for_locale(locale)
          end
        end

        def currencies_for_locale(locale) do
          {:error, Locale.locale_error(locale)}
        end

        @doc """
        Get currency data for a locale or raise

        ## Arguments

        * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
          or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

        """
        @spec currencies_for_locale!(Locale.name() | LanguageTag.t()) ::
                Map.t() | no_return

        def currencies_for_locale!(locale) do
          case currencies_for_locale(locale) do
            {:ok, currencies} -> currencies
            {:error, {exception, reason}} -> raise exception, reason
          end
        end

        @doc """
        Returns the string and symbols for a currency that
        can be used to parse money

        ## Arguments

        * `locale` is any valid locale name returned by `Cldr.known_locale_names/1`
          or a `Cldr.LanguageTag` struct returned by `Cldr.Locale.new!/2`

        * `currency_status` is `:all`, `:current`, `:historic` or `:tender`
          or a list of one or more status. The default is `:all`

        """
        @spec currency_strings(Cldr.Locale.t, Cldr.Currency.currency_status) :: Map.t
        def currency_strings(locale, currency_status \\ :all)

        def currency_strings(%LanguageTag{} = locale, currency_status) do
          {:ok, currencies} = currencies_for_locale(locale)
          for {currency_code, currency} <- currencies, currency_filter(currency, currency_status) do
            strings =
              [currency.name, currency.symbol, currency.code] ++ Map.values(currency.count)
              |> Enum.reject(&is_nil/1)
              |> Enum.map(&String.downcase/1)
              |> Enum.uniq

            {currency_code, strings}
          end
          |> Map.new
        end

        def currency_strings(locale_name, currency_status) when is_binary(locale_name) do
          with {:ok, locale} <- Cldr.validate_locale(locale_name, unquote(backend)) do
            currency_strings(locale, currency_status)
          end
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

        @doc """
        Returns all currency strings for all known locales

        ## Arguments

        * `currency_status` is `:all`, `:current`, `:historic` or `:tender`
          or a list of one or more status. The default is `:all`

        """
        @spec all_currency_strings(Cldr.Currency.currency_status) :: Map.t
        def all_currency_strings(currency_status \\ :all) do
          for locale_name <- unquote(backend).known_locale_names -- ["root"] do
            currency_strings(locale_name, currency_status)
          end
          |> merge_maps
          |> Enum.map(fn {k, v} -> {k, Enum.uniq(v)} end)
          |> Map.new
        end

        defp merge_maps(maps) do
          Enum.reduce(maps, %{}, fn m, acc ->
            Map.merge(acc, m, fn _k, m1, m2 -> m1 ++ m2 end)
          end)
        end

        @doc false
        def duplicate_narrow_symbols(currency_status \\ :all) do
          [locale_name | _] = unquote(backend).known_locale_names -- ["root"]
          currencies =
            locale_name
            |> currencies_for_locale!
            |> currency_filter(currency_status)
            |> Enum.map(fn {_c, m} -> m.narrow_symbol end)
            |> Enum.reject(&is_nil/1)
            |> Enum.group_by(fn x -> x end)
            |> Enum.filter(fn {k, l} -> length(l) > 1 end)
            |> Map.new
            |> Map.keys
        end
      end
    end
  end
end