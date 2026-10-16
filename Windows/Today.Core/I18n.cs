using System.Globalization;

namespace Today.Core;

// Only presentation is localized; storage and user-written text are never translated.
public static class I18n
{
    public static bool IsRussian(CultureInfo culture) => culture.TwoLetterISOLanguageName == "ru";
    public static string Text(string russian, string english) => IsRussian(CultureInfo.CurrentUICulture) ? russian : english;
    public static CultureInfo Culture => CultureInfo.GetCultureInfo(IsRussian(CultureInfo.CurrentUICulture) ? "ru-RU" : "en-US");
}
