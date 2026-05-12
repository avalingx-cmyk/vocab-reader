/// GBNF grammar for constraining local LLM output to valid word summary JSON.
///
/// This grammar enforces that the model outputs a JSON object with exactly
/// these fields: definition, useCases, similarWords.
///
/// Usage: Pass this to SamplerParams.grammarStr with grammarRoot = "root"
const String wordSummaryGrammar = r'''
root ::= "{" space definition-kv "," space use-cases-kv "," space similar-words-kv "}" space
definition-kv ::= "\"definition\"" space ":" space string
use-cases-kv ::= "\"useCases\"" space ":" space array
similar-words-kv ::= "\"similarWords\"" space ":" space array
array ::= "[" space (string ("," space string)*)? "]" space
string ::= "\"" char* "\"" space
char ::= [^"\\] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4})
space ::= | " " | "\n" [ \t]{0,20}
''';

/// Alternative stricter grammar that requires at least 1 item in each array.
/// Use this if the model produces empty arrays too often.
const String wordSummaryGrammarStrict = r'''
root ::= "{" space definition-kv "," space use-cases-kv "," space similar-words-kv "}" space
definition-kv ::= "\"definition\"" space ":" space string
use-cases-kv ::= "\"useCases\"" space ":" space "[" space string ("," space space string)+ "]" space
similar-words-kv ::= "\"similarWords\"" space ":" space "[" space string ("," space space string)+ "]" space
string ::= "\"" char* "\"" space
char ::= [^"\\] | "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4})
space ::= | " " | "\n" [ \t]{0,20}
''';
