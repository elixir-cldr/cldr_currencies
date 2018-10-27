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

        """
        @spec currencies_for_locale(Locale.name() | LanguageTag.t()) ::
                {:ok, Map.t()} | {:error, {Exception.t(), String.t()}}
        def currencies_for_locale(locale)

        for locale_name <- Cldr.Config.known_locale_names(config) do
          currencies =
            locale_name
            |> Cldr.Config.get_locale()
            |> Map.get(:currencies)
            |> Enum.map(fn {k, v} -> {k, struct(Cldr.Currency, v)} end)
            |> Enum.into(%{})

          def currencies_for_locale(%LanguageTag{cldr_locale_name: unquote(locale_name)}) do
            {:ok, unquote(Macro.escape(currencies))}
          end
        end

        def currencies_for_locale(locale_name) when is_binary(locale_name) do
          case Locale.canonical_language_tag(locale_name, unquote(backend)) do
            {:ok, locale} -> currencies_for_locale(locale)
            {:error, reason} -> {:error, reason}
          end
        end

        def currencies_for_locale(locale) do
          {:error, Locale.locale_error(locale)}
        end
      end
    end
  end
end