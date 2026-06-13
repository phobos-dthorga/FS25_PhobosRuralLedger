# Known Log Lines

No accepted Phobos-owned runtime errors or warnings are currently documented
for release candidates.

Use this file only for temporary known lines that are understood, owned, and
scheduled for removal.

## Runtime Ownership Triage

```text
Line: Warning: Could not retrieve GUI profile 'button'. Using base reference profile instead.
Owner: Ownership pending after v0.1.5.3
Status: Former Phobos-owned blocker; v0.1.5.3 loads dedicated Rural Ledger profiles before the screen XML, but the latest log still shows repeated generic 'button' warnings before the Rural Ledger GUI load messages.
Cause: Unknown in the current mixed-mod runtime log. If the warning appears during or after Rural Ledger profile/screen load, it is a Phobos-owned hard miss.
Target: v0.1.6.1 runtime verification
Removal condition: Runtime log from a disposable save has no Rural Ledger-owned GUI profile warnings after opening and using the Rural Ledger screen, selecting Farmers rows, enabling the footer Farm Detail and Opportunities actions, double-clicking Farmers rows, opening/closing the Farm Detail and Opportunities dialogs, saving/reloading, and confirming Rural Ledger button/tab/footer interactions show no distortion.
```

```text
Line: Error: Game save failed. Error: 7
Owner: External unless it appears only after Rural Ledger save hook execution
Status: Runtime acceptance blocker if it appears during the dedicated opportunity save/reload proof.
Cause: Previously observed in mixed-mod logs without a Phobos-owned stack. Runtime testing of v0.1.6.0 also showed no Rural Ledger save-attempt lines and no dedicated XML file, so v0.1.6.1 adds explicit hook/path/write diagnostics before this line can be classified safely.
Target: v0.1.6.1 runtime verification
Removal condition: Disposable save/reload test writes `FS25_PhobosRuralLedger.xml`, reloads it cleanly, and has no Phobos-owned save warnings/errors or unexplained save failure lines.
```

## Entry Template

```text
Line:
Owner:
Status:
Cause:
Target:
Removal condition:
```
