class NumberToWords {
  static const List<String> units = [
    "", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"
  ];
  static const List<String> teens = [
    "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf"
  ];
  static const List<String> tens = [
    "", "dix", "vingt", "trente", "quarante", "cinquante", "soixante", "soixante-dix", "quatre-vingt", "quatre-vingt-dix"
  ];

  static String convert(int number) {
    if (number == 0) return "zéro";
    if (number < 0) return "moins " + convert(-number);

    String result = "";

    if ((number / 1000000).floor() > 0) {
      int millions = (number / 1000000).floor();
      result += (millions == 1 ? "un million " : convert(millions) + " millions ");
      number %= 1000000;
    }

    if ((number / 1000).floor() > 0) {
      int thousands = (number / 1000).floor();
      result += (thousands == 1 ? "mille " : convert(thousands) + " mille ");
      number %= 1000;
    }

    if ((number / 100).floor() > 0) {
      int hundreds = (number / 100).floor();
      result += (hundreds == 1 ? "cent " : convert(hundreds) + " cents ");
      number %= 100;
    }

    if (number > 0) {
      if (number < 10) {
        result += units[number];
      } else if (number < 20) {
        result += teens[number - 10];
      } else if (number < 100) {
        int t = (number / 10).floor();
        int u = number % 10;
        
        if (t == 7) {
          result += "soixante-" + (u == 1 ? "et-onze" : teens[u]);
        } else if (t == 9) {
          result += "quatre-vingt-" + teens[u];
        } else {
          result += tens[t] + (u == 1 ? (t == 8 ? "-un" : "-et-un") : (u > 0 ? "-" + units[u] : ""));
        }
      }
    }

    return result.trim().toUpperCase();
  }

  static String convertToFr(double amount) {
    int wholePart = amount.floor();
    return convert(wholePart) + " FRANCS CFA";
  }
}
