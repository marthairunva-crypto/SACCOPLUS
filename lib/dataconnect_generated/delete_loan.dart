part of 'generated.dart';

class DeleteLoanVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteLoanVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteLoanData> dataDeserializer = (dynamic json)  => DeleteLoanData.fromJson(jsonDecode(json));
  Serializer<DeleteLoanVariables> varsSerializer = (DeleteLoanVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteLoanData, DeleteLoanVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteLoanData, DeleteLoanVariables> ref() {
    DeleteLoanVariables vars= DeleteLoanVariables(id: id,);
    return _dataConnect.mutation("DeleteLoan", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteLoanLoanDelete {
  final String id;
  DeleteLoanLoanDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteLoanLoanDelete otherTyped = other as DeleteLoanLoanDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteLoanLoanDelete({
    required this.id,
  });
}

@immutable
class DeleteLoanData {
  final DeleteLoanLoanDelete? loan_delete;
  DeleteLoanData.fromJson(dynamic json):
  
  loan_delete = json['loan_delete'] == null ? null : DeleteLoanLoanDelete.fromJson(json['loan_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteLoanData otherTyped = other as DeleteLoanData;
    return loan_delete == otherTyped.loan_delete;
    
  }
  @override
  int get hashCode => loan_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (loan_delete != null) {
      json['loan_delete'] = loan_delete!.toJson();
    }
    return json;
  }

  DeleteLoanData({
    this.loan_delete,
  });
}

@immutable
class DeleteLoanVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteLoanVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteLoanVariables otherTyped = other as DeleteLoanVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteLoanVariables({
    required this.id,
  });
}

