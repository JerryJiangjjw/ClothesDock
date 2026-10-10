import Testing
@testable import ClothesDock

struct DockPreferenceTests {
    @Test func defaultsReadBooleanFormatsBecomeWriteLiterals() {
        for raw in ["1", "true", "TRUE", "yes", " 1\n"] { #expect(DockPreferenceValue.booleanLiteral(raw) == "true") }
        for raw in ["0", "false", "FALSE", "no", " 0\n"] { #expect(DockPreferenceValue.booleanLiteral(raw) == "false") }
        #expect(DockPreferenceValue.booleanLiteral("unexpected") == nil)
        #expect(DockPreferenceValue.booleanLiteral("") == nil)
    }
}
