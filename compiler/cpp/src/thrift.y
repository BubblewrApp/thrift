%{

/**
 * Thrift parser.
 *
 * This parser is used on a thrift definition file.
 *
 * @author Mark Slee <mcslee@facebook.com>
 */

#include <stdio.h>
#include "main.h"
#include "globals.h"
#include "parse/t_program.h"
#include "parse/t_scope.h"

/**
 * This global variable is used for automatic numbering of field indices etc.
 * when parsing the members of a struct. Field values are automatically
 * assigned starting from -1 and working their way down.
 */
int y_field_val = -1;

%}

/**
 * This structure is used by the parser to hold the data types associated with
 * various parse nodes.
 */
%union {
  char*          id;
  int            iconst;
  double         dconst;
  bool           tbool;
  t_type*        ttype;
  t_typedef*     ttypedef;
  t_enum*        tenum;
  t_enum_value*  tenumv;
  t_const*       tconst;
  t_const_value* tconstv;
  t_struct*      tstruct;
  t_service*     tservice;
  t_function*    tfunction;
  t_field*       tfield;
}

/**
 * Strings identifier
 */
%token<id>     tok_identifier
%token<id>     tok_literal

/**
 * Constant values
 */
%token<iconst> tok_int_constant
%token<dconst> tok_dub_constant

/**
 * Header keywoards
 */
%token tok_include
%token tok_namespace
%token tok_cpp_namespace
%token tok_cpp_include
%token tok_cpp_type
%token tok_php_namespace
%token tok_java_package
%token tok_xsd_all
%token tok_xsd_optional

/**
 * Base datatype keywords
 */
%token tok_void
%token tok_bool
%token tok_byte
%token tok_string
%token tok_slist
%token tok_i16
%token tok_i32
%token tok_i64
%token tok_double

/**
 * Complex type keywords
 */
%token tok_map
%token tok_list
%token tok_set

/**
 * Function modifiers
 */ 
%token tok_async

/**
 * Thrift language keywords
 */
%token tok_typedef
%token tok_struct
%token tok_xception
%token tok_throws
%token tok_extends
%token tok_service
%token tok_enum
%token tok_const

/**
 * Grammar nodes
 */

%type<ttype>     BaseType
%type<ttype>     ContainerType
%type<ttype>     MapType
%type<ttype>     SetType
%type<ttype>     ListType

%type<ttype>     TypeDefinition

%type<ttypedef>  Typedef
%type<ttype>     DefinitionType

%type<tfield>    Field
%type<ttype>     FieldType
%type<tstruct>   FieldList

%type<tenum>     Enum
%type<tenum>     EnumDefList
%type<tenumv>    EnumDef

%type<tconst>    Const
%type<tconstv>   ConstValue
%type<tconstv>   ConstList
%type<tconstv>   ConstListContents
%type<tconstv>   ConstMap
%type<tconstv>   ConstMapContents

%type<tstruct>   Struct
%type<tstruct>   Xception
%type<tservice>  Service

%type<tfunction> Function
%type<ttype>     FunctionType
%type<tservice>  FunctionList

%type<tstruct>   Throws
%type<tservice>  Extends
%type<tbool>     Async
%type<tbool>     XsdAll
%type<tbool>     XsdOptional
%type<id>        CppType

%%

/**
 * Thrift Grammar Implementation.
 *
 * For the most part this source file works its way top down from what you
 * might expect to find in a typical .thrift file, i.e. type definitions and
 * namespaces up top followed by service definitions using those types.
 */

Program:
  HeaderList DefinitionList
    {
      pdebug("Program -> Headers DefinitionList");
    }

HeaderList:
  HeaderList Header
    {
      pdebug("HeaderList -> HeaderList Header");
    }
|
    {
      pdebug("HeaderList -> ");
    }

Header:
  Include
    {
      pdebug("Header -> Include");
    }
| tok_namespace tok_identifier
    {
      pwarning(1, "'namespace' is deprecated. Use 'cpp_namespace' and/or 'java_package' instead");
      if (g_parse_mode == PROGRAM) {
        g_program->set_cpp_namespace($2);
        g_program->set_java_package($2);
      }
    }
| tok_cpp_namespace tok_identifier
    {
      pdebug("Header -> tok_cpp_namespace tok_identifier");
      if (g_parse_mode == PROGRAM) {
        g_program->set_cpp_namespace($2);
      }
    }
| tok_cpp_include tok_literal
    {
      pdebug("Header -> tok_cpp_include tok_literal");
      if (g_parse_mode == PROGRAM) {
        g_program->add_cpp_include($2);
      }
    }
| tok_php_namespace tok_identifier
    {
      pdebug("Header -> tok_php_namespace tok_identifier");
      if (g_parse_mode == PROGRAM) {
        g_program->set_php_namespace($2);
      }
    }
| tok_java_package tok_identifier
    {
      pdebug("Header -> tok_java_package tok_identifier");
      if (g_parse_mode == PROGRAM) {
        g_program->set_java_package($2);
      }
    }

Include:
  tok_include tok_literal
    {
      pdebug("Include -> tok_include tok_literal");     
      if (g_parse_mode == INCLUDES) {
        std::string path = include_file(std::string($2));
        if (!path.empty()) {
          g_program->add_include(path);
        }
      }
    }

DefinitionList:
  DefinitionList Definition
    {
      pdebug("DefinitionList -> DefinitionList Definition");
    }
|
    {
      pdebug("DefinitionList -> ");
    }

Definition:
  Const
    {
      pdebug("Definition -> Const");
      if (g_parse_mode == PROGRAM) {
        g_program->add_const($1);
      }    
    }
| TypeDefinition
    {
      pdebug("Definition -> TypeDefinition");
      if (g_parse_mode == PROGRAM) {
        g_scope->add_type($1->get_name(), $1);
        if (g_parent_scope != NULL) {
          g_parent_scope->add_type(g_parent_prefix + $1->get_name(), $1);
        }
      }
    }
| Service
    {
      pdebug("Definition -> Service");
      if (g_parse_mode == PROGRAM) {
        g_scope->add_service($1->get_name(), $1);
        if (g_parent_scope != NULL) {
          g_parent_scope->add_service(g_parent_prefix + $1->get_name(), $1);
        }
        g_program->add_service($1);
      }
    }

TypeDefinition:
  Typedef
    {
      pdebug("TypeDefinition -> Typedef");
      if (g_parse_mode == PROGRAM) {
        g_program->add_typedef($1);
      }
    }
| Enum
    {
      pdebug("TypeDefinition -> Enum");
      if (g_parse_mode == PROGRAM) {
        g_program->add_enum($1);
      }
    }
| Struct
    {
      pdebug("TypeDefinition -> Struct");
      if (g_parse_mode == PROGRAM) {
        g_program->add_struct($1);
      }
    }
| Xception
    { 
      pdebug("TypeDefinition -> Xception");
      if (g_parse_mode == PROGRAM) {
        g_program->add_xception($1);
      }
    }

Typedef:
  tok_typedef DefinitionType tok_identifier
    {
      pdebug("TypeDef -> tok_typedef DefinitionType tok_identifier");
      t_typedef *td = new t_typedef(g_program, $2, $3);
      $$ = td;
    }

Enum:
  tok_enum tok_identifier '{' EnumDefList '}'
    {
      pdebug("Enum -> tok_enum tok_identifier { EnumDefList }");
      $$ = $4;
      $$->set_name($2);
    }

CommaOrSemicolonOptional:
  ','
    {}
| ';'
    {}
|
    {}

EnumDefList:
  EnumDefList EnumDef
    {
      pdebug("EnumDefList -> EnumDefList EnumDef");
      $$ = $1;
      $$->append($2);
    }
|
    {
      pdebug("EnumDefList -> ");
      $$ = new t_enum(g_program);
    }

EnumDef:
  tok_identifier '=' tok_int_constant CommaOrSemicolonOptional
    {
      pdebug("EnumDef -> tok_identifier = tok_int_constant");
      if ($3 < 0) {
        pwarning(1, "Negative value supplied for enum %s.\n", $1);
      }
      $$ = new t_enum_value($1, $3);
    }
|
  tok_identifier CommaOrSemicolonOptional
    {
      pdebug("EnumDef -> tok_identifier");
      $$ = new t_enum_value($1);
    }

Const:
  tok_const FieldType tok_identifier '=' ConstValue CommaOrSemicolonOptional
    {
      pdebug("Const -> tok_const FieldType tok_identifier = ConstValue");
      if (g_parse_mode == PROGRAM) {
        $$ = new t_const($2, $3, $5);
        validate_const_type($$);
      } else {
        $$ = NULL;
      }
    }

ConstValue:
  tok_int_constant
    {
      pdebug("ConstValue => tok_int_constant");
      $$ = new t_const_value();
      $$->set_integer($1);
    }
| tok_dub_constant
    {
      pdebug("ConstValue => tok_dub_constant");
      $$ = new t_const_value();
      $$->set_double($1);
    }
| tok_literal
    {
      pdebug("ConstValue => tok_literal");
      $$ = new t_const_value();
      $$->set_string($1);
    }
| tok_identifier
    {
      pdebug("ConstValue => tok_identifier");
      $$ = new t_const_value();
      $$->set_string($1);
    }
| ConstList
    {
      pdebug("ConstValue => ConstList");
      $$ = $1;
    }
| ConstMap
    {
      pdebug("ConstValue => ConstMap");
      $$ = $1; 
    }

ConstList:
  '[' ConstListContents ']'
    {
      pdebug("ConstList => [ ConstListContents ]");
      $$ = $2;
    }

ConstListContents:
  ConstListContents ConstValue CommaOrSemicolonOptional
    {
      pdebug("ConstListContents => ConstListContents ConstValue CommaOrSemicolonOptional");
      $$ = $1;
      $$->add_list($2);
    }
|
    {
      pdebug("ConstListContents =>");
      $$ = new t_const_value();
      $$->set_list();
    }

ConstMap:
  '{' ConstMapContents '}'
    {
      pdebug("ConstMap => { ConstMapContents }");
      $$ = $2;
    }

ConstMapContents:
  ConstMapContents ConstValue ':' ConstValue CommaOrSemicolonOptional
    {
      pdebug("ConstMapContents => ConstMapContents ConstValue CommaOrSemicolonOptional");
      $$ = $1;
      $$->add_map($2, $4);
    }
|
    {
      pdebug("ConstMapContents =>");
      $$ = new t_const_value();
      $$->set_map();
    }

Struct:
  tok_struct tok_identifier XsdAll '{' FieldList '}'
    {
      pdebug("Struct -> tok_struct tok_identifier { FieldList }");
      $5->set_name($2);
      $5->set_xsd_all($3);
      $$ = $5;
      y_field_val = -1;
    }

XsdAll:
  tok_xsd_all
    {
      $$ = true;
    }
|
    {
      $$ = false;
    }

XsdOptional:
  tok_xsd_optional
    {
      $$ = true;
    }
|
    {
      $$ = false;
    }

Xception:
  tok_xception tok_identifier '{' FieldList '}'
    {
      pdebug("Xception -> tok_xception tok_identifier { FieldList }");
      $4->set_name($2);
      $4->set_xception(true);
      $$ = $4;
      y_field_val = -1;
    }

Service:
  tok_service tok_identifier Extends '{' FunctionList '}'
    {
      pdebug("Service -> tok_service tok_identifier { FunctionList }");
      $$ = $5;
      $$->set_name($2);
      $$->set_extends($3);
    }

Extends:
  tok_extends tok_identifier
    {
      pdebug("Extends -> tok_extends tok_identifier");
      $$ = NULL;
      if (g_parse_mode == PROGRAM) {
        $$ = g_scope->get_service($2);
        if ($$ == NULL) {
          yyerror("Service \"%s\" has not been defined.", $2);
          exit(1);
        }
      }
    }
|
    {
      $$ = NULL;
    }

FunctionList:
  FunctionList Function
    {
      pdebug("FunctionList -> FunctionList Function");
      $$ = $1;
      $1->add_function($2);
    }
|
    {
      pdebug("FunctionList -> ");
      $$ = new t_service(g_program);
    }

Function:
  Async FunctionType tok_identifier '(' FieldList ')' Throws CommaOrSemicolonOptional
    {
      $5->set_name(std::string($3) + "_args");
      $$ = new t_function($2, $3, $5, $7, $1);
      y_field_val = -1;
    }

Async:
  tok_async
    {
      $$ = true;
    }
|
    {
      $$ = false;
    }

Throws:
  tok_throws '(' FieldList ')'
    {
      pdebug("Throws -> tok_throws ( FieldList )");
      $$ = $3;
    }
|
    {
      $$ = new t_struct(g_program);
    }

FieldList:
  FieldList Field
    {
      pdebug("FieldList -> FieldList , Field");
      $$ = $1;
      $$->append($2);
    }
|
    {
      pdebug("FieldList -> ");
      $$ = new t_struct(g_program);
    }

Field:
  tok_int_constant ':' FieldType tok_identifier XsdOptional CommaOrSemicolonOptional
    {
      pdebug("tok_int_constant : Field -> FieldType tok_identifier");
      if ($1 <= 0) {
        pwarning(1, "Nonpositive value (%d) not allowed as a field key for '%s'.\n", $1, $4);
        $1 = y_field_val--;
      }
      $$ = new t_field($3, $4, $1);
      $$->set_xsd_optional($5);
    }
| FieldType tok_identifier XsdOptional CommaOrSemicolonOptional
    {
      pdebug("Field -> FieldType tok_identifier");
      pwarning(2, "No field key specified for '%s', resulting protocol may have conflicts or not be backwards compatible!\n", $2);
      $$ = new t_field($1, $2, y_field_val--);
      $$->set_xsd_optional($3);
    }
| FieldType tok_identifier '=' tok_int_constant CommaOrSemicolonOptional
    {
      pwarning(1, "Trailing = id notation is deprecated. Use 'Id: Type Name' notation instead"); 
      pdebug("Field -> FieldType tok_identifier = tok_int_constant");
      if ($4 <= 0) {
        pwarning(1, "Nonpositive value (%d) not allowed as a field key for '%s'.\n", $4, $2);
        $4 = y_field_val--;
      }
      $$ = new t_field($1, $2, $4);
    }

DefinitionType:
  BaseType
    {
      pdebug("DefinitionType -> BaseType");
      $$ = $1;
    }
| ContainerType
    {
      pdebug("DefinitionType -> ContainerType");
      $$ = $1;
    }

FunctionType:
  FieldType
    {
      pdebug("FunctionType -> FieldType");
      $$ = $1;
    }
| tok_void
    {
      pdebug("FunctionType -> tok_void");
      $$ = g_type_void;
    }

FieldType:
  tok_identifier
    {
      pdebug("FieldType -> tok_identifier");
      if (g_parse_mode == INCLUDES) {
        // Ignore identifiers in include mode
        $$ = NULL;
      } else {
        // Lookup the identifier in the current scope
        $$ = g_scope->get_type($1);
        if ($$ == NULL) {
          yyerror("Type \"%s\" has not been defined.", $1);
          exit(1);
        }
      }
    }
| BaseType
    {
      pdebug("FieldType -> BaseType");
      $$ = $1;
    }
| ContainerType
    {
      pdebug("FieldType -> ContainerType");
      $$ = $1;
    }

BaseType:
  tok_string
    {
      pdebug("BaseType -> tok_string");
      $$ = g_type_string;
    }
| tok_slist
    {
      pdebug("BaseType -> tok_slist");
      $$ = g_type_slist;
    }
| tok_bool
    {
      pdebug("BaseType -> tok_bool");
      $$ = g_type_bool;
    }
| tok_byte
    {
      pdebug("BaseType -> tok_byte");
      $$ = g_type_byte;
    }
| tok_i16
    {
      pdebug("BaseType -> tok_i16");
      $$ = g_type_i16;
    }
| tok_i32
    {
      pdebug("BaseType -> tok_i32");
      $$ = g_type_i32;
    }
| tok_i64
    {
      pdebug("BaseType -> tok_i64");
      $$ = g_type_i64;
    }
| tok_double
    {
      pdebug("BaseType -> tok_double");
      $$ = g_type_double;
    }

ContainerType:
  MapType
    {
      pdebug("ContainerType -> MapType");
      $$ = $1;
    }
| SetType
    {
      pdebug("ContainerType -> SetType");
      $$ = $1;
    }
| ListType
    {
      pdebug("ContainerType -> ListType");
      $$ = $1;
    }

MapType:
  tok_map CppType '<' FieldType ',' FieldType '>'
    {
      pdebug("MapType -> tok_map <FieldType, FieldType>");
      $$ = new t_map($4, $6);
      if ($2 != NULL) {
        ((t_container*)$$)->set_cpp_name(std::string($2));
      }
    }

SetType:
  tok_set CppType '<' FieldType '>'
    {
      pdebug("SetType -> tok_set<FieldType>");
      $$ = new t_set($4);
      if ($2 != NULL) {
        ((t_container*)$$)->set_cpp_name(std::string($2));
      }
    }

ListType:
  tok_list '<' FieldType '>' CppType
    {
      pdebug("ListType -> tok_list<FieldType>");
      $$ = new t_list($3);
      if ($5 != NULL) {
        ((t_container*)$$)->set_cpp_name(std::string($5));
      }
    }

CppType:
  '[' tok_cpp_type tok_literal ']'
    {
      $$ = $3;
    }
|
    {
      $$ = NULL;
    }

%%
