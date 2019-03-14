# Changelog for Cldr_Currencies v2.2.4

This is the changelog for Cldr_Currencies v2.2.4 released on March 15th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Enhancements

* Makes generation of documentation for backend modules optional.  This is implemented by the `:generate_docs` option to the backend configuration.  The default is `true`. For example:

```
defmodule MyApp.Cldr do
  use Cldr,
    default_locale: "en-001",
    locales: ["en", "ja"],
    gettext: MyApp.Gettext,
    generate_docs: false
end

# Changelog for Cldr_Currencies v2.2.3

This is the changelog for Cldr_Currencies v2.2.3 released on March 7th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Fix or silence all remaining dialyzer warnings for real this time

# Changelog for Cldr_Currencies v2.2.2

This is the changelog for Cldr_Currencies v2.2.2 released on March 7th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Fix or silence all remaining dialyzer warnings

# Changelog for Cldr_Currencies v2.2.1

This is the changelog for Cldr_Currencies v2.2.1 released on March 6th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Fix or silence dialyzer warnings

# Changelog for Cldr_Currencies v2.2.0

This is the changelog for Cldr_Currencies v2.2.0 released on February 23nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Enhancements

This release adds mapping data from a territory to a list of currencies and functions to access them. This allows for identifying the current currency for a given locale.

* Adds `Cldr.Currency.currency_history_for_locale/2`
* Adds `Cldr.Currency.current_currency_for_locale/2`
* Adds `Cldr.Currency.territory_currencies/0`

Some examples:
```
iex> Cldr.Currency.territory_currencies |> Map.get("LT")
%{
  EUR: %{from: ~D[2015-01-01], to: nil},
  LTL: %{from: nil, to: ~D[2014-12-31]},
  LTT: %{from: nil, to: ~D[1993-06-25]},
  SUR: %{from: nil, to: ~D[1992-10-01]}
}

iex> Cldr.Currency.currency_history_for_locale "en", MyApp.Cldr
%{
  USD: %{from: ~D[1792-01-01], to: nil},
  USN: %{tender: false},
  USS: %{from: nil, tender: false, to: ~D[2014-03-01]}
}

iex> Cldr.Currency.current_currency_for_locale "en", MyApp.Cldr
:USD

iex> Cldr.Currency.current_currency_for_locale "en-AU", MyApp.Cldr
:AUD
```

# Changelog for Cldr_Currencies v2.1.4

This is the changelog for Cldr_Currencies v2.1.4 released on February 22nd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Fixes significant performance regression in `Cldr.Currency.currencies_for_locale/2`.  Thanks to @doughsay for the issue.  Closes #98 in [money](https://github.com/kipcole9/money).

# Changelog for Cldr_Currencies v2.1.3

This is the changelog for Cldr_Currencies v2.1.3 released on February 18th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Updates `ex_cldr` to fix the regex that parses currency names used for money parsing

# Changelog for Cldr_Currencies v2.1.2

This is the changelog for Cldr_Currencies v2.1.2 released on February 13th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Some different currencies may have the same currency name.  This most commonly happens when there are historic currencies with the same name as a current currency. Afghan Afghanis, for example, has the code `:AFA` until 2002 when it was replaced by the currency code `:AFN`.  Now when extracting currency strings, the currency names map only to the current currency and the duplicated are therefore removed.

# Changelog for Cldr_Currencies v2.1.1

This is the changelog for Cldr_Currencies v2.1.1 released on February 10th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Bug Fixes

* Fixes the regex for parsing currency names that have date ranges in them. It now correctly parses names with non-ASCII characters too.

* Removes `Cldr.Currency.all_currency_strings/2` since strings conflict across locales

* Add `Cldr.Currency.currency_strings/2`

### Enhancements

* Added `:unannotated` to `Cldr.Currency.currency_filter/2`.  It omits currency names that have a "(...)" in then since these are typically financial instruments.

# Changelog for Cldr_Currencies v2.1.0

This is the changelog for Cldr_Currencies v2.1.0 released on February 9th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Enhancements

The primary goal of this release is to provide a mechanism to support parsing money and currency input from a user. With this in mind, this release adds:

* `Cldr.Currency.currency_strings/2` that returns a list of strings for a currency in a locale against which user input can be compared to identify a currency

* `Cldr.Currency.all_currency_strings/2` which returns a similar list but for all known locales

* `Cldr.Currency.currency_filter/2` that will filter a list currencies based upon whether they are current, historic or legal tender

In addition the `Cldr.Currency.t` structure has changed:

* The `Cldr.Currency.t` struct now includes effective dates `:to` and `:from`.  These were previously encoded in the currency name.  The currency name no longer includes these dates.

# Changelog for Cldr_Currencies v2.0.0

This is the changelog for Cldr_Currencies v2.0.0 released on November 22nd, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Enhancements

* Updated dependency on [ex_cldr](https://hex.pm/packages/ex_cldr) to version 2.0.0.
* Remove Poison from optional dependencies (can still be configured in a client app)

### Breaking Changes

* `Currency.currency_for_code/3` has a changed function signature and it now requires a backend module to be specified.  It also supports an option `:locale` to specify the locale. The default is the default locale of the specified backend.
```
  Cldr.Currency.currency_for_locale(:USD, MyApp.Cldr, locale: "en")
```
The @spec for the new signature is:
```
  @spec currency_for_code(code, Cldr.backend(), Keyword.t()) ::
          {:ok, t} | {:error, {module(), String.t()}}
```