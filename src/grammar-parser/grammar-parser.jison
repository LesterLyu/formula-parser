/* description: Parses end evaluates mathematical expressions. */

/* lexical grammar */
%lex
%%

\s+
{/* skip whitespace */}
'"'("\\"["]|[^"])*'"'                                                                           {return 'STRING';}
"'"((?![\\\/\[\]\*\?\:]).)+?"'"(?=!)                                                            {return 'REFSHEET';}
"'"('\\'[']|[^'])*"'"                                                                           {return 'STRING';}
[A-Za-z]{1,}[A-Za-z_0-9\.]+(?=[(])                                                              {return 'FUNCTION';}
'#'[A-Z0-9\/]+('!'|'?')?                                                                        {return 'ERROR';}
'$'[A-Za-z]+'$'[0-9]+                                                                           {return 'ABSOLUTE_CELL';}
'$'[A-Za-z]+[0-9]+                                                                              {return 'MIXED_CELL';}
[A-Za-z]+'$'[0-9]+                                                                              {return 'MIXED_CELL';}
[A-Za-z]+[0-9]+(?![!])                                                                          {return 'RELATIVE_CELL';}
[A-Za-z_\.\d]+(?=[!])                                                                           {return 'REFSHEET';}
[A-Za-z\.]+(?=[(])                                                                              {return 'FUNCTION';}
[A-Za-z]{1,}[A-Za-z_0-9]+                                                                       {return 'VARIABLE';}
[A-Za-z_]+                                                                                      {return 'VARIABLE';}
[0-9]+                                                                                          {return 'NUMBER';}
'['([\w\,\;\s]*)?']'                                                                            {return 'ARRAY';}
'{'([\w\,\;\"\.\s]*)?'}'                                                                        {return 'ARRAYCONSTANT';}
"&"                                                                                             {return '&';}
" "                                                                                             {return ' ';}
[.]                                                                                             {return 'DECIMAL';}
":"                                                                                             {return ':';}
";"                                                                                             {return ';';}
","                                                                                             {return ',';}
"*"                                                                                             {return '*';}
"/"                                                                                             {return '/';}
"-"                                                                                             {return '-';}
"+"                                                                                             {return '+';}
"^"                                                                                             {return '^';}
"("                                                                                             {return '(';}
")"                                                                                             {return ')';}
">"                                                                                             {return '>';}
"<"                                                                                             {return '<';}
"NOT"                                                                                           {return 'NOT';}
'"'                                                                                             {return '"';}
"'"                                                                                             {return "'";}
"!"                                                                                             {return "!";}
"="                                                                                             {return '=';}
"%"                                                                                             {return '%';}
"{"                                                                                             {return '{';}
"}"                                                                                             {return '}';}
[#]                                                                                             {return '#';}
<<EOF>>                                                                                         {return 'EOF';}
/lex

/* operator associations and precedence (low-top, high-bottom) */
%left '='
%left '<=' '>=' '<>' 'NOT' '||'
%left '>' '<'
%left '+' '-'
%left '*' '/'
%left '^'
%left '&'
%left '%'
%left '!'
%left UMINUS

%start expressions

%% /* language grammar */

expressions
  : expression EOF {
      return $1;
    }
;

expression
  : variableSequence {
      $$ = yy.callVariable($1[0]);
    }
  | number {
      $$ = yy.toNumber($1);
    }
  | STRING {
      $$ = yy.trimEdges($1);
    }
  | expression '&' expression {
      $$ = yy.evaluateByOperator('&', [$1, $3]);
    }
  | expression '=' expression {
      $$ = yy.evaluateByOperator('=', [$1, $3]);
    }
  | expression '+' expression {
      $$ = yy.evaluateByOperator('+', [$1, $3]);
    }
  | '(' expression ')' {
      $$ = $2;
    }
  | expression '<' '=' expression {
      $$ = yy.evaluateByOperator('<=', [$1, $4]);
    }
  | expression '>' '=' expression {
      $$ = yy.evaluateByOperator('>=', [$1, $4]);
    }
  | expression '<' '>' expression {
      $$ = yy.evaluateByOperator('<>', [$1, $4]);
    }
  | expression NOT expression {
      $$ = yy.evaluateByOperator('NOT', [$1, $3]);
    }
  | expression '>' expression {
      $$ = yy.evaluateByOperator('>', [$1, $3]);
    }
  | expression '<' expression {
      $$ = yy.evaluateByOperator('<', [$1, $3]);
    }
  | expression '-' expression {
      $$ = yy.evaluateByOperator('-', [$1, $3]);
    }
  | expression '*' expression {
      $$ = yy.evaluateByOperator('*', [$1, $3]);
    }
  | expression '/' expression {
      $$ = yy.evaluateByOperator('/', [$1, $3]);
    }
  | expression '^' expression {
      $$ = yy.evaluateByOperator('^', [$1, $3]);
    }
  | '-' expression {
      var n1 = yy.invertNumber($2);

      $$ = n1;

      if (isNaN($$)) {
          $$ = 0;
      }
    }
  | '+' expression {
      var n1 = yy.toNumber($2);

      $$ = n1;

      if (isNaN($$)) {
          $$ = 0;
      }
    }
  | FUNCTION '(' ')' {
      $$ = yy.callFunction($1);
    }
  | FUNCTION '(' expseq ')' {
      $$ = yy.callFunction($1, $3);
    }
  | ARRAYCONSTANT {
      var result = [];

      var textInArray = yytext.replace('{','').replace('}','');

      var arr = textInArray.split(';');
      if(arr.length <= 1) {
        var arr = eval("[[" + arr + "]]");
        arr.forEach(function(item) {
          result.push(item);
        });
      } else {
        for(var i = 0; i < arr.length; i++) {
          result.push(eval("[" + arr[i] + "]"));
        }
      }

      $$ = result;
  }
  | ARRAY {
      var result = [];
      var arr = eval("[" + yytext + "]");

      arr.forEach(function(item) {
        result.push(item);
      });
      $$ = result;
  }
  | cell
  | refCell
  | range
  | refRange
  | error
  | error error
;

cell
  : ABSOLUTE_CELL {
      $$ = yy.cellValue($1);
    }
  | RELATIVE_CELL {
      $$ = yy.cellValue($1);
    }
  | MIXED_CELL {
      $$ = yy.cellValue($1);
    }
  ;

refCell
  : REFSHEET '!' ABSOLUTE_CELL {

      $$ = yy.cellValue($3, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' RELATIVE_CELL {
      $$ = yy.cellValue($3, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' MIXED_CELL {
    $$ = yy.cellValue($3, $1.replace(/'/g, ""));
  }
;

range
  : ABSOLUTE_CELL ':' ABSOLUTE_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | ABSOLUTE_CELL ':' RELATIVE_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | ABSOLUTE_CELL ':' MIXED_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | RELATIVE_CELL ':' ABSOLUTE_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | RELATIVE_CELL ':' RELATIVE_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | RELATIVE_CELL ':' MIXED_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | MIXED_CELL ':' ABSOLUTE_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | MIXED_CELL ':' RELATIVE_CELL {
      $$ = yy.rangeValue($1, $3);
    }
  | MIXED_CELL ':' MIXED_CELL {
      $$ = yy.rangeValue($1, $3);
    }
;

refRange
  : REFSHEET '!' ABSOLUTE_CELL ':' ABSOLUTE_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' ABSOLUTE_CELL ':' RELATIVE_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' ABSOLUTE_CELL ':' MIXED_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' RELATIVE_CELL ':' ABSOLUTE_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' RELATIVE_CELL ':' RELATIVE_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' RELATIVE_CELL ':' MIXED_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' MIXED_CELL ':' ABSOLUTE_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' MIXED_CELL ':' RELATIVE_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
  | REFSHEET '!' MIXED_CELL ':' MIXED_CELL {
      $$ = yy.rangeValue($3, $5, $1.replace(/'/g, ""));
    }
;

expseq
  : expression {
      $$ = [$1];
    }
  | expseq ';' expression {
      $1.push($3);
      $$ = $1;
    }
  | expseq ',' expression {
      $1.push($3);
      $$ = $1;
    }
;

variableSequence
  : VARIABLE {
      $$ = [$1];
    }
  | variableSequence DECIMAL VARIABLE {
      $$ = (Array.isArray($1) ? $1 : [$1]);
      $$.push($3);
    }
;

number
  : NUMBER {
      $$ = $1;
    }
  | NUMBER DECIMAL NUMBER {
      $$ = ($1 + '.' + $3) * 1;
    }
  | number '%' {
      $$ = $1 * 0.01;
    }
;

error
  : ERROR {
      $$ = yy.throwError($1);
    }
;

%%
