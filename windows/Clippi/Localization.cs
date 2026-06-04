using Microsoft.Windows.ApplicationModel.Resources;

namespace Clippi
{
    internal static class L10n
    {
        private static readonly ResourceLoader Loader = new();

        public static string Get(string key)
        {
            var value = Loader.GetString(key);
            return string.IsNullOrEmpty(value) ? key : value;
        }

        public static string Format(string key, params object[] args)
        {
            return string.Format(Get(key), args);
        }
    }
}
