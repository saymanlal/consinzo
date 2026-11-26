declare module "solc" {
  interface SolcImportResult {
    contents?: string;
    error?: string;
  }
  interface SolcExport {
    compile(
      input: string,
      callbacks?: {
        import?: (path: string) => SolcImportResult;
      }
    ): string;
    version(): string;
  }
  const solc: SolcExport;
  export default solc;
}
