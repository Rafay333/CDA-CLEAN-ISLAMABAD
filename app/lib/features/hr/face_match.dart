/// Phone-side face rules. Matching happens on the server (InsightFace / ArcFace embeddings).
///
/// matchPercent is a DISPLAY scale from the server: the server's real accept cutoff
/// (cosine similarity 0.40) is shown as 62%. Anything the server rejects never reaches the phone,
/// so this 60% check is only a second safety net.
const minAcceptMatchPercent = 60;

const alreadyRegisteredMessage = 'This user is already registered.';
const faceRegisteredSuccessMessage = 'Face registered successfully.';

bool isStrongFaceMatch(int? matchPercent) =>
    matchPercent != null && matchPercent >= minAcceptMatchPercent;

/// This employee already has a face on the server (409, stale roster).
bool isThisEmployeeAlreadyEnrolledError(String message) {
  final text = message.toLowerCase().trim();
  if (text.contains('already registered under')) return false;
  return text == 'face already registered.' ||
      text == 'face already registered' ||
      text.contains('already enrolled') ||
      (text.contains('already registered') && !text.contains('under'));
}

/// Server thinks the face belongs to a different employee record.
bool isDuplicateOfOtherEmployeeError(String message) {
  return message.toLowerCase().contains('already registered under');
}

String? otherEmployeeFromDuplicateError(String message) {
  final match = RegExp(
    r'already registered under\s+(.+?)(?:\.|$)',
    caseSensitive: false,
  ).firstMatch(message);
  return match?.group(1)?.trim();
}

/// Legacy helper — prefer the two functions above in enroll UI.
bool isAlreadyRegisteredError(String message) {
  return isThisEmployeeAlreadyEnrolledError(message) || isDuplicateOfOtherEmployeeError(message);
}
