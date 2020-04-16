defmodule Cldr.Currency.Backend do
  @moduledoc false

  def define_currency_module(config) do
    require Cldr
    require Cldr.Currency

    module = inspect(__MODULE__)
    backend = config.backend
    config = Macro.escape(config)

    quote location: :keep, bind_quoted: [module: module, backend: backend, config: config] do
      defmodule Currency do
        unless Cldr.Config.include_module_docs?(config.generate_docs) do
          @moduledoc false
        end

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
        @spec new(Cldr.Currency.code(), map() | Keyword.t) ::
          {:ok, Cldr.Currency.t} | {:error, {module(), String.t}}

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

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`. The
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
                {:ok, String.t()} | {:error, {module(), String.t()}}

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
          Cldr.Currency.known_currencies()
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
        @spec known_currency?(Cldr.Currency.code(), list(Cldr.Currency.t())) :: boolean

        def known_currency?(currency_code, custom_currencies \\ []) do
          Cldr.Currency.known_currency?(currency_code, custom_currencies)
        end

        @doc """
        Returns the effective currency for a given locale

        ## Arguments

        * `locale` is a `Cldr.LanguageTag` struct returned by
          `Cldr.Locale.new!/2`

        ## Returns

        * A ISO 4217 currency code as an upcased atom

        ## Examples

            iex> {:ok, locale} = #{inspect backend}.validate_locale "en"
            iex> #{inspect __MODULE__}.currency_from_locale locale
            :USD

            iex> {:ok, locale} = #{inspect backend}.validate_locale "en-AU"
            iex> #{inspect __MODULE__}.currency_from_locale locale
            :AUD

            iex> #{inspect __MODULE__}.currency_from_locale "en-GB"
            :GBP

        """

        def currency_from_locale(%LanguageTag{} = locale) do
          Cldr.Currency.currency_from_locale(locale)
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
        def currency_from_locale(locale) when is_binary(locale) do
          Cldr.Currency.currency_from_locale(locale, unquote(backend))
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
        @spec currency_for_code(Cldr.Currency.code, Keyword.t()) ::
                {:ok, Cldr.Currency.t} | {:error, {module(), String.t()}}

        def currency_for_code(
              currency_code,
              options \\ [locale: unquote(backend).default_locale()]
            ) do
          Cldr.Currency.currency_for_code(currency_code, unquote(backend), options)
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

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_map}` or

        * `{:error, {exception, reason}}`

        ## Example

          MyApp.Cldr.Currency.currencies_for_locale "en"
          => {:ok,
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
        @spec currencies_for_locale(
                Cldr.Locale.locale_name() | LanguageTag.t(),
                only :: Cldr.Currency.filter(),
                except :: Cldr.Currency.filter()
              ) ::
                {:ok, map()} | {:error, {module(), String.t()}}

        @dialyzer {:nowarn_function, currencies_for_locale: 3}

        def currencies_for_locale(locale, only \\ :all, except \\ nil)

        @doc """
        Returns a map that matches a currency string to a
        currency code.

        A currency string is a localised name or symbol
        representing a currency in a locale-specific manner.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_string_map}` or

        * `{:error, {exception, reason}}`

        ## Example

            MyApp.Cldr.Currency.currency_strings "en"
            => {:ok,
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

        """
        @spec currency_strings(Cldr.LanguageTag.t() | Cldr.Locale.locale_name(),
                only :: Cldr.Currency.filter(),
                except :: Cldr.Currency.filter()) ::
                {:ok, map()} | {:error, {module(), String.t()}}

        @dialyzer {:nowarn_function, currency_strings: 3}

        def currency_strings(locale, only \\ :all, except \\ nil)

        for locale_name <- Cldr.Config.known_locale_names(config) do
          currencies =
            locale_name
            |> Cldr.Config.currencies_for!(config)
            |> Enum.map(fn {k, v} -> {k, struct(Cldr.Currency, v)} end)
            |> Map.new()

          currency_strings =
            for {currency_code, currency} <- Cldr.Config.currencies_for!(locale_name, config) do
              strings =
                ([currency.name, currency.symbol, currency.code] ++ Map.values(currency.count))
                |> Enum.reject(&is_nil/1)
                |> Enum.map(&String.downcase/1)
                |> Enum.map(&String.trim_trailing(&1, "."))
                |> Enum.uniq()

              {currency_code, strings}
            end

          inverted_currency_strings =
            Cldr.Currency.invert_currency_strings(currency_strings)
            |> Cldr.Currency.remove_duplicate_strings(currencies)
            |> Map.new

          def currencies_for_locale(
                %LanguageTag{cldr_locale_name: unquote(locale_name)},
                only, except
              ) do
            filtered_currencies =
              unquote(Macro.escape(currencies))
              |> Cldr.Currency.currency_filter(only, except)

            {:ok, filtered_currencies}
          end

          def currency_strings(%LanguageTag{cldr_locale_name: unquote(locale_name)}, :all, nil) do
            {:ok, unquote(Macro.escape(inverted_currency_strings))}
          end
        end

        def currencies_for_locale(locale_name, only, except) when is_binary(locale_name) do
          with {:ok, locale} <- Cldr.validate_locale(locale_name, unquote(backend)) do
            currencies_for_locale(locale, only, except)
          end
        end

        def currencies_for_locale(locale, _only, _except) do
          {:error, Cldr.Locale.locale_error(locale)}
        end

        def currency_strings(locale_name, only, except) when is_binary(locale_name) do
          with {:ok, locale} <- Cldr.validate_locale(locale_name, unquote(backend)) do
            currency_strings(locale, only, except)
          end
        end

        def currency_strings(%LanguageTag{} = locale, only, except) do
          with {:ok, currencies} <- currencies_for_locale(locale) do
            filtered_currencies =
              currencies
              |> Cldr.Currency.currency_filter(only, except)

            currency_codes =
              filtered_currencies
              |> Map.keys()

            strings =
              locale
              |> currency_strings!
              |> Enum.filter(fn {_k, v} -> v in currency_codes end)
              |> Cldr.Currency.remove_duplicate_strings(filtered_currencies)
              |> Map.new()

            {:ok, strings}
          end
        end

        def currency_strings(locale, _only, _except) do
          {:error, Cldr.Locale.locale_error(locale)}
        end

        @doc """
        Returns a map of the metadata for all currencies for
        a given locale and raises on error.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_map}` or

        * raises an exception

        ## Example

          MyApp.Cldr.Currency.currencies_for_locale! "en"
          => %{
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
        @spec currencies_for_locale(Cldr.Locale.locale_name() | LanguageTag.t(),
          only :: Cldr.Currency.filter(), except :: Cldr.Currency.filter()) ::
          map() | no_return()

        def currencies_for_locale!(locale, only \\ :all, except \\ nil) do
          case currencies_for_locale(locale, only, except) do
            {:ok, currencies} -> currencies
            {:error, {exception, reason}} -> raise exception, reason
          end
        end

        @doc """
        Returns a map that matches a currency string to a
        currency code or raises an exception.

        A currency string is a localised name or symbol
        representing a currency in a locale-specific manner.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        * `currency_status` is `:all`, `:current`, `:historic`,
          `unannotated` or `:tender`; or a list of one or more status.
          The default is `:all`. See `Cldr.Currency.currency_filter/2`.

        ## Returns

        * `{:ok, currency_string_map}` or

        * raises an exception

        ## Example

            MyApp.Cldr.Currency.currency_strings! "en"
            => %{
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
                only :: Cldr.Currency.filter(), except :: Cldr.Currency.filter()) ::
                map() | no_return()

        def currency_strings!(locale_name, only \\ :all, except \\ nil) do
          case currency_strings(locale_name, only, except) do
            {:ok, currency_strings} -> currency_strings
            {:error, {exception, reason}} -> raise exception, reason
          end
        end

        @doc """
        Returns the strings associated with a currency
        in a given locale.

        ## Arguments

        * `currency` is an ISO4217 currency code

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        ## Returns

        * A list of strings or

        * `{:error, {exception, reason}}`

        ## Example

            iex> MyApp.Cldr.Currency.strings_for_currency :AUD, "en"
            ["a$", "australian dollars", "aud", "australian dollar"]

        """
        def strings_for_currency(currency, locale) do
          Cldr.Currency.strings_for_currency(currency, locale, unquote(backend))
        end

        @doc """
        Returns a list of historic and the current
        currency for a given locale.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        ## Example

            iex> MyApp.Cldr.Currency.currency_history_for_locale "en"
            {:ok,
                %{
                USD: %{from: ~D[1792-01-01], to: nil},
                USN: %{tender: false},
                USS: %{from: nil, tender: false, to: ~D[2014-03-01]}
              }
            }

        """
        @spec currency_history_for_locale(LanguageTag.t | Cldr.Locale.locale_name) ::
          map() | {:error, {module(), String.t}}

        def currency_history_for_locale(%LanguageTag{} = language_tag) do
          Cldr.Currency.currency_history_for_locale(language_tag)
        end

        def currency_history_for_locale(locale_name) when is_binary(locale_name) do
          Cldr.Currency.currency_history_for_locale(locale_name, unquote(backend))
        end

        @doc """
        Returns the current currency for a given locale.

        This function does not consider the `U` extenion
        parameters `cu` or `rg`. It is recommended to us
        `Cldr.Currency.currency_from_locale/1` in most
        circumstances.

        ## Arguments

        * `locale` is any valid locale name returned by `MyApp.Cldr.known_locale_names/0`
          or a `Cldr.LanguageTag` struct returned by `MyApp.Cldr.Locale.new!/1`

        ## Example

            iex> MyApp.Cldr.Currency.current_currency_from_locale "en"
            :USD

            iex> MyApp.Cldr.Currency.current_currency_from_locale "en-AU"
            :AUD

        """
        def current_currency_from_locale(%LanguageTag{} = locale) do
          Cldr.Currency.current_currency_from_locale(locale)
        end

        def current_currency_from_locale(locale_name) when is_binary(locale_name) do
          Cldr.Currency.current_currency_from_locale(locale_name, unquote(backend))
        end
      end
    end
  end
end
