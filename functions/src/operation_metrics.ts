/**
 * Counts the Firestore work this process can observe. It is intentionally not a
 * billing meter: Firestore may add index-entry reads and transaction retries.
 * Values are safe operational telemetry and contain no request payloads.
 */
export class OperationMetrics {
  private readonly startedAtMs = Date.now();
  private directDocumentReads = 0;
  private queryCalls = 0;
  private queryDocuments = 0;
  private plannedDocumentWrites = 0;
  private transactionAttempts = 0;

  public readDocument(count = 1): void {
    this.directDocumentReads += count;
  }

  public readQuery(returnedDocuments: number): void {
    this.queryCalls += 1;
    this.queryDocuments += returnedDocuments;
  }

  public writeDocument(count = 1): void {
    this.plannedDocumentWrites += count;
  }

  public transactionAttempt(): void {
    this.transactionAttempts += 1;
  }

  public logFields(): Record<string, number> {
    return {
      durationMs: Math.max(0, Date.now() - this.startedAtMs),
      observedDocumentReads: this.directDocumentReads + this.queryDocuments,
      directDocumentReads: this.directDocumentReads,
      queryCalls: this.queryCalls,
      queryDocuments: this.queryDocuments,
      plannedDocumentWrites: this.plannedDocumentWrites,
      transactionAttempts: this.transactionAttempts
    };
  }
}
