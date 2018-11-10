# Changelog for Cldr_Currencies v2.0.0-rc.0

This is the changelog for Cldr_Currencies v1.1.0 released on November 10th, 2018.  For older changelogs please consult the release tag on [GitHub](https://github.com/kipcole9/cldr_currencies/tags)

### Enhancements

* Updated dependency on [ex_cldr](https://hex.pm/packages/ex_cldr) to version 2.0.0-rc.0
* Remove Poison from optional dependencies (can still be configured in a cliuent app)

### Breaking Changes

* `Currency.currency_for_code/3` has a changed function signature that requires a backend module to be specified.  It also supports an option `:locale` to specify the locale. The default is the default locale of the specified backend.
```
  Cldr.Currency.currency_for_locale(:USD, MyApp.Cldr, locale: "en")
```
The @spec for the new signature is:
```
  @spec currency_for_code(code, Cldr.backend(), Keyword.t()) ::
          {:ok, t} | {:error, {Exception.t(), String.t()}}
```