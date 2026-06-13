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
Status: Runtime acceptance noise unless Rural Ledger logs a save failure directly.
Cause: The user reports this FS25 line is omnipresent in mixed-mod saves. For Rural Ledger, classify persistence by Phobos-owned lines such as `Rural Ledger opportunity save written`, `Rural Ledger opportunity save loaded`, or explicit Rural Ledger save warnings.
Target: v0.1.6.2 runtime verification
Removal condition: Disposable save/reload test writes `FS25_PhobosRuralLedger.xml`, reloads it cleanly, and has no Phobos-owned save warnings/errors.
```

```text
Line: [PhobosRuralLedger][WARN] Rural Ledger opportunity save unavailable while writing: xml_api_unavailable.
Owner: PhobosRuralLedger
Status: Historical v0.1.6.1 blocker; resolved by the local XML adapter path.
Cause: Rural Ledger could not see the retired shared XML wrapper at runtime. The current build uses the global FS25 `XMLFile` API directly.
Target: v0.1.7.0 runtime verification
Removal condition: Saving with v0.1.7.0 logs `Rural Ledger opportunity save written to ...FS25_PhobosRuralLedger.xml` and no longer logs `xml_api_unavailable`.
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
