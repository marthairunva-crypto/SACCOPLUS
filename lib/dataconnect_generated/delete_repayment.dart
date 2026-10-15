part of 'generated.dart';

class DeleteRepaymentVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteRepaymentVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteRepaymentData> dataDeserializer = (dynamic json)  => DeleteRepaymentData.fromJson(jsonDecode(json));
  Serializer<DeleteRepaymentVariables> varsSerializer = (DeleteRepaymentVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteRepaymentData, DeleteRepaymentVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteRepaymentData, DeleteRepaymentVariables> ref() {
    DeleteRepaymentVariables vars= DeleteRepaymentVariables(id: id,);
    return _dataConnect.mutation("DeleteRepayment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteRepaymentLoanRepaymentDelete {
  final String id;
  DeleteRepaymentLoanRepaymentDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteRepaymentLoanRepaymentDelete otherTyped = other as DeleteRepaymentLoanRepaymentDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteRepaymentLoanRepaymentDelete({
    required this.id,
  });
}

@immutable
class DeleteRepaymentData {
  final DeleteRepaymentLoanRepaymentDelete? loanRepayment_delete;
  DeleteRepaymentData.fromJson(dynamic json):
  
  loanRepayment_delete = json['loanRepayment_delete'] == null ? null : DeleteRepaymentLoanRepaymentDelete.fromJson(json['loanRepayment_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteRepaymentData otherTyped = other as DeleteRepaymentData;
    return loanRepayment_delete == otherTyped.loanRepayment_delete;
    
  }
  @override
  int get hashCode => loanRepayment_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (loanRepayment_delete != null) {
      json['loanRepayment_delete'] = loanRepayment_delete!.toJson();
    }
    return json;
  }

  DeleteRepaymentData({
    this.loanRepayment_delete,
  });
}

@immutable
class DeleteRepaymentVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteRepaymentVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteRepaymentVariables otherTyped = other as DeleteRepaymentVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteRepaymentVariables({
    required this.id,
  });
}

