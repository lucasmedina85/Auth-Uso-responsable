class MrzData {
  String documentType;
  String nationality;
  String documentNumber;
  int birthYear;
  int birthMonth;
  int birthDay;
  String sex;
  String lastName;
  String firstName;
  
  MrzData({
    required this.documentType,
    required this.nationality,
    required this.documentNumber,
    required this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    required this.sex,
    required this.lastName,
    required this.firstName,
  });
}

MrzData? parseMrz(String line1, String line2, String line3) {
  try {
    // Line 1: IDARG31980196<1<<<<<<<<<<<<<<<
    String docType = line1.substring(0, 2); // ID
    String nationality = line1.substring(2, 5); // ARG
    String docNum = line1.substring(5, 14).replaceAll('<', '').trim(); // 31980196
    
    // Line 2: 8511113M4005069ARG<<<<<<<<<<<0
    String yy = line2.substring(0, 2);
    String mm = line2.substring(2, 4);
    String dd = line2.substring(4, 6);
    String sex = line2.substring(7, 8); // M or F
    
    int currentYear = DateTime.now().year % 100;
    int yearInt = int.parse(yy);
    int fullYear = (yearInt > currentYear) ? 1900 + yearInt : 2000 + yearInt;
    
    // Line 3: MEDINA<BRITO<<LUCAS<EMMANUEL<< (or similar)
    // The user provided MEDINA<BRITO<LUCAS<EMMANUEL<< which has only single <
    // Usually it's LastName<<FirstName
    String names = line3.replaceAll(RegExp(r'<+$'), ''); // remove trailing
    List<String> parts = names.split('<<');
    
    String lastNames = '';
    String firstNames = '';
    
    if (parts.length >= 2) {
      lastNames = parts[0].replaceAll('<', ' ').trim();
      firstNames = parts[1].replaceAll('<', ' ').trim();
    } else {
      // User's exact example: MEDINA<BRITO<LUCAS<EMMANUEL
      // Without << we can't perfectly separate last and first, but let's assume half/half or split by <
      List<String> words = names.split('<');
      if (words.length >= 4) {
         lastNames = "${words[0]} ${words[1]}";
         firstNames = "${words[2]} ${words[3]}";
      } else {
         lastNames = names.replaceAll('<', ' ').trim();
      }
    }
    
    return MrzData(
      documentType: docType,
      nationality: nationality,
      documentNumber: docNum,
      birthYear: fullYear,
      birthMonth: int.parse(mm),
      birthDay: int.parse(dd),
      sex: sex,
      lastName: lastNames,
      firstName: firstNames,
    );
  } catch (e) {
    print(e);
    return null;
  }
}

void main() {
  var res = parseMrz(
    "IDARG31980196<1<<<<<<<<<<<<<<<",
    "8511113M4005069ARG<<<<<<<<<<<0",
    "MEDINA<BRITO<LUCAS<EMMANUEL<<"
  );
  print("${res?.documentNumber} ${res?.birthYear}-${res?.birthMonth}-${res?.birthDay} ${res?.lastName} ${res?.firstName}");
}
