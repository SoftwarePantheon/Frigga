parser grammar FriggaParser;

options { tokenVocab=FriggaLexer; }

literal
    : IntLiteral
    | DecLiteral
    | CharLiteral
    | BoolLiteral
    | StringLiteral
    | tupleLiteral
    ;

/*
* Tuples
* Tuple literals can be made with either named syntax (eg `(age: 30, name: "Steve")`)
* or indexed syntax (eg `(30, "Steve"))
*/

tupleLiteral
    : namedTupleLiteral
    | indexedTupleLiteral
    ;

indexedTupleLiteral
    : LPAREN indexedTupleValues RPAREN
    ;

indexedTupleValues
    : (expression COMMA expression)+
    ;


namedTupleLiteral
    : LPAREN namedTupleValues RPAREN
    ;

namedTupleValues
    :(namedTupleValue COMMA namedTupleValue)+
    ;

namedTupleValue
    : ID COLON expression
    ;


type
    : structType //eg StructName
    | nothingType //_
    | functionType //eg (Int) -> _
    | tupleType //eg (name: String, age: Int)
    ;

nothingType
    : UNDERSCORE
    ;

structType
    : ID typeArguments?
    ;

functionType
    : LPAREN functionTypeParameterTypes RPAREN ARROW functionTypeReturnType
    ;

functionTypeParameterTypes
    :  type? (COMMA type) *
    ;

functionTypeReturnType
    : type
    ;

tupleType
    : LPAREN tupleTypeParam (COMMA tupleTypeParam)? RPAREN
    ;
tupleTypeParam
    : ID COLON type
    ;


typeArguments //eg <Int, String>
    : '<' typeArgumentList '>'
    ;

typeArgumentList //eg Int, String
    : typeArgument (COMMA typeArgument)*
    ;

typeArgument //eg Int - this will be improved on in future to add things like wildcards
    : type
    ;

/*
* Names
*/

namespaceName
    : ID
    | namespaceName '/' ID
    ;

javaPackageName
    : ID (DOT javaPackageName)*
    ;

useNamespaceName
    : namespaceName
    | JVM COLON javaPackageName
    ;

structName
    : ID
    | namespaceName '/' ID
    ;

/*
* Headers
*/

header
    : (namespaceDeclaration)? (useDeclaration)*
    ;

namespaceDeclaration
    : NAMESPACE namespaceName
    ;

useDeclaration
    : USE useNamespaceName
    ;

friggaFile
    : header body EOF
    ;


/*
* Body
*/

body
    : lines
    ;

lines
    : (line)*
    ;



line
    : statement #statementLine
    | assignableExpression #expressionLine
    ;

untypedPropertyDeclaration
    : propertyModifier* ID
    ;

typedPropertyDeclaration
    : propertyModifier* ID propertyType
    ;

propertyType
	:  DOUBLE_COLON type
	;

//Declaring a property (ie creating one)
//For example: List.functionName = () -> _ { blah }
propertyCreation
	: extensionDefinition?
	  (untypedPropertyDeclaration | typedPropertyDeclaration)
	  ASSIGN assignableExpression
	;

//Assigning an already existing property (eg prop.value = 3)
propertyAssignment
    : propertyAccess propertyType?
      ASSIGN assignableExpression
    ;

extensionDefinition
    :
    type DOT
    ;

//Declaring a property only. eg age::Int
propertyDeclaration
    : typedPropertyDeclaration //for native properties (and possibly more in the future)
    ;

propertyModifier
    : NATIVE
    | SECRET
    | MUTABLE
    ;

/*
* Functions
*/

functionValue
    : functionSignature functionBody
    ;

functionBody
    : LCPAREN body RCPAREN
    ;

functionSignature
    : typeSignature? functionArguments ARROW type
    ;

functionArguments
    : LPAREN (functionArgument? (COMMA functionArgument)*) RPAREN
    ;

functionArgument
    : ID DOUBLE_COLON type
    ;

typeSignature
    : '<' typeParameters '>'
    ;

typeParameters
    : typeParameter (COMMA typeParameter)*
    ;

typeParameter
    : ID (DOUBLE_COLON type)?
    ;


/*
* Statements
*/
statement
    : propertyCreation    #propertyCreationStatement
    | propertyAssignment  #propertyAssignmentStatement
	| propertyDeclaration #propertyDeclarationStatement
    | structDeclaration   #structDeclarationStatement
    | traitDeclaration    #traitDeclarationStatement
    ;

/*
* Expressions
*/
propertyAccess //eg SomeStruct.prop or someValue.prop or prop
    : propertyAccess DOT ID #childAccess
    | structName #directAccess
    ;

referencedCall
    :
      typeSignature? refererencedCallParameters
    ;

refererencedCallParameters
    : LSPAREN functionCallParametersList RSPAREN
    ;

functionCallParameters
    : LPAREN functionCallParametersList RPAREN
    ;

functionCall
    :
      typeSignature? functionCallParameters functionBody?
    ;


functionCallParametersList
    : (indexedFunctionCallParameter? (COMMA indexedFunctionCallParameter)*) //Indexed calls
    | (namedFunctionCallParameter? (COMMA namedFunctionCallParameter)*) //named calls
    ;


indexedFunctionCallParameter // 3
    : assignableExpression
    ;

namedFunctionCallParameter //age: 30
    : ID COLON assignableExpression
    ;


prefixOperatorCall
    :
       operator=(NOT | BIN_NOT)
       right=expression
    ;


//Expresssions that can be used in assignment (eg x = 3) but cannot be used stanalone (eg 3, 3 + 2,  or () -> {})
assignableExpression
    : literal #literalExpression
    | functionValue #functionExpression
    | lambdaValue #lambdaExpression
    | left=assignableExpression
      operator=binaryOperation
      right=assignableExpression #binaryOperatorExpression //3 + 4
    | expression #otherExpression
    | LPAREN assignableExpression RPAREN #parenthesisedExpression //(blah)
    ;

//Parts of code that can be written anywhere
expression
    : expression functionCall #callExpression //blah("hello")
    | expression referencedCall #referencedCallExpression //blah["hello"]
    | prefixOperatorCall #prefixOperatorExpression //!true
    | expression DOT ID #accessExpression //a.b
    | propertyAccess #propertyAccessExpression //a
    | expression ID expression #infixCallExpression //"a" to "b"
    ;

binaryOperation
    : POWER | TIMES | DIVIDE | PLUS | MINUS | EQUAL | NOT_EQUAL | MORE_THAN | MORE_EQUAL_THAN | LESS_THAN | LESS_EQUAL_THAN
    ;
/*
* Lambdas
*/

lambdaValue
    : functionBody #blockLambda //eg { println("Hello") }
    | functionArguments ARROW assignableExpression #typedSingleExpressionLambda //single expression typed lambda eg (a::Int) -> blah(a)
    | lambdaArguments ARROW assignableExpression #untypedSingleExpressionLambda //single expression untyped lambda eg (a) -> blah(a)
    | functionArguments ARROW functionBody #blockTypedParamsLambda //block typed lambda
    | lambdaArguments ARROW functionBody #blockUntypedParamsLambda //block untyped lambda
    ;

lambdaArguments
    : LPAREN ID (COMMA ID)* RPAREN;


/*
* Structs and Traits
*/

structDeclaration
    : STRUCT ID typeSignature? structParentDeclaration?
    structBody?
    ;

traitDeclaration
    : TRAIT ID typeSignature? structParentDeclaration?
    structBody?
    ;

structBody
    : LCPAREN
    statement*
    RCPAREN
    ;

structParentDeclaration
    : COLON
    ID (COMMA ID)*
    ;
