/**
 * Counts the Firestore work this process can observe. It is intentionally not a
 * billing meter: Firestore may add index-entry reads and transaction retries.
 * Values are safe operational telemetry and contain no request payloads.
 */
export interface OperationMark {
  readonly atMs: number;
  readonly directDocumentReads: number;
  readonly queryCalls: number;
  readonly queryDocuments: number;
  readonly plannedDocumentWrites: number;
  readonly transactionAttempts: number;
}

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
    return this.fieldsSince({
      atMs: this.startedAtMs,
      directDocumentReads: 0,
      queryCalls: 0,
      queryDocuments: 0,
      plannedDocumentWrites: 0,
      transactionAttempts: 0
    });
  }

  /** Where the counters stand now, to log one step alone with [logFieldsSince]. */
  public mark(): OperationMark {
    return {
      atMs: Date.now(),
      directDocumentReads: this.directDocumentReads,
      queryCalls: this.queryCalls,
      queryDocuments: this.queryDocuments,
      plannedDocumentWrites: this.plannedDocumentWrites,
      transactionAttempts: this.transactionAttempts
    };
  }

  /**
   * Only the work done after [mark] (e.g. the XP grant that follows a submit,
   * which otherwise would log the submit's reads a second time).
   */
  public logFieldsSince(mark: OperationMark): Record<string, number> {
    return this.fieldsSince(mark);
  }

  private fieldsSince(mark: OperationMark): Record<string, number> {
    const direct = this.directDocumentReads - mark.directDocumentReads;
    const queryDocuments = this.queryDocuments - mark.queryDocuments;
    return {
      durationMs: Math.max(0, Date.now() - mark.atMs),
      observedDocumentReads: direct + queryDocuments,
      directDocumentReads: direct,
      queryCalls: this.queryCalls - mark.queryCalls,
      queryDocuments,
      plannedDocumentWrites: this.plannedDocumentWrites - mark.plannedDocumentWrites,
      transactionAttempts: this.transactionAttempts - mark.transactionAttempts
    };
  }
}
