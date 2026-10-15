part of 'generated.dart';

class DeleteAccountVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteAccountVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteAccountData> dataDeserializer = (dynamic json)  => DeleteAccountData.fromJson(jsonDecode(json));
  Serializer<DeleteAccountVariables> varsSerializer = (DeleteAccountVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteAccountData, DeleteAccountVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteAccountData, DeleteAccountVariables> ref() {
    DeleteAccountVariables vars= DeleteAccountVariables(id: id,);
    return _dataConnect.mutation("DeleteAccount", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteAccountAccountDelete {
  final String id;
  DeleteAccountAccountDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteAccountAccountDelete otherTyped = other as DeleteAccountAccountDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteAccountAccountDelete({
    required this.id,
  });
}

@immutable
class DeleteAccountData {
  final DeleteAccountAccountDelete? account_delete;
  DeleteAccountData.fromJson(dynamic json):
  
  account_delete = json['account_delete'] == null ? null : DeleteAccountAccountDelete.fromJson(json['account_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteAccountData otherTyped = other as DeleteAccountData;
    return account_delete == otherTyped.account_delete;
    
  }
  @override
  int get hashCode => account_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (account_delete != null) {
      json['account_delete'] = account_delete!.toJson();
    }
    return json;
  }

  DeleteAccountData({
    this.account_delete,
  });
}

@immutable
class DeleteAccountVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteAccountVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteAccountVariables otherTyped = other as DeleteAccountVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteAccountVariables({
    required this.id,
  });
}

