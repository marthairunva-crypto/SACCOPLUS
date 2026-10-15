part of 'generated.dart';

class CreateLoanVariablesBuilder {
  double principal;
  double interest;
  DateTime dueDate;

  final FirebaseDataConnect _dataConnect;
  CreateLoanVariablesBuilder(this._dataConnect, {required  this.principal,required  this.interest,required  this.dueDate,});
  Deserializer<CreateLoanData> dataDeserializer = (dynamic json)  => CreateLoanData.fromJson(jsonDecode(json));
  Serializer<CreateLoanVariables> varsSerializer = (CreateLoanVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateLoanData, CreateLoanVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateLoanData, CreateLoanVariables> ref() {
    CreateLoanVariables vars= CreateLoanVariables(principal: principal,interest: interest,dueDate: dueDate,);
    return _dataConnect.mutation("CreateLoan", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateLoanLoanInsert {
  final String id;
  CreateLoanLoanInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateLoanLoanInsert otherTyped = other as CreateLoanLoanInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateLoanLoanInsert({
    required this.id,
  });
}

@immutable
class CreateLoanData {
  final CreateLoanLoanInsert loan_insert;
  CreateLoanData.fromJson(dynamic json):
  
  loan_insert = CreateLoanLoanInsert.fromJson(json['loan_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateLoanData otherTyped = other as CreateLoanData;
    return loan_insert == otherTyped.loan_insert;
    
  }
  @override
  int get hashCode => loan_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['loan_insert'] = loan_insert.toJson();
    return json;
  }

  CreateLoanData({
    required this.loan_insert,
  });
}

@immutable
class CreateLoanVariables {
  final double principal;
  final double interest;
  final DateTime dueDate;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateLoanVariables.fromJson(Map<String, dynamic> json):
  
  principal = nativeFromJson<double>(json['principal']),
  interest = nativeFromJson<double>(json['interest']),
  dueDate = nativeFromJson<DateTime>(json['dueDate']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateLoanVariables otherTyped = other as CreateLoanVariables;
    return principal == otherTyped.principal && 
    interest == otherTyped.interest && 
    dueDate == otherTyped.dueDate;
    
  }
  @override
  int get hashCode => Object.hashAll([principal.hashCode, interest.hashCode, dueDate.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['principal'] = nativeToJson<double>(principal);
    json['interest'] = nativeToJson<double>(interest);
    json['dueDate'] = nativeToJson<DateTime>(dueDate);
    return json;
  }

  CreateLoanVariables({
    required this.principal,
    required this.interest,
    required this.dueDate,
  });
}

