/// GBNF grammar for constraining local LLM output to valid word summary JSON.
///
/// This grammar enforces that the model outputs a JSON object with exactly
/// these fields: definition, useCases, similarWords.
///
/// Usage: Pass this to SamplerParams.grammarStr with grammarRoot = "root"
const String wordSummaryGrammar = r'''
root ::= "{" definition-kv "," use-cases-kv "," similar-words-kv "}"
definition-kv ::= "\"definition\"" ":" string
use-cases-kv ::= "\"useCases\"" ":" array
similar-words-kv ::= "\"similarWords\"" ":" array
array ::= "[" (string ("," string)*)? "]"
string ::= "\"" char* "\""
char ::= [^"\\] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4})
''';

const String wordSummaryGrammarStrict = r'''
root ::= "{" definition-kv "," use-cases-kv "," similar-words-kv "}"
definition-kv ::= "\"definition\"" ":" string
use-cases-kv ::= "\"useCases\"" ":" "[" string ("," string)+ "]"
similar-words-kv ::= "\"similarWords\"" ":" "[" string ("," string)+ "]"
string ::= "\"" char+ "\""
char ::= [^"\\] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4})
''';
