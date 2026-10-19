/// Stub e implementação para ambiente Web (browser sandbox).
/// Em navegadores, não há acesso a binários nativos de SO ou arquivos locais de root.
List<String> checkPlatformRootAndJailbreak({
  required List<String> androidRootPaths,
  required List<String> iosJailbreakPaths,
}) {
  return <String>[];
}
