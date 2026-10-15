part of 'generated.dart';

class DeleteTransactionVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteTransactionVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteTransactionData> dataDeserializer = (dynamic json)  => DeleteTransactionData.fromJson(jsonDecode(json));
  Serializer<DeleteTransactionVariables> varsSerializer = (DeleteTransactionVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteTransactionData, DeleteTransactionVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteTransactionData, DeleteTransactionVariables> ref() {
    DeleteTransactionVariables vars= DeleteTransactionVariables(id: id,);
    return _dataConnect.mutation("DeleteTransaction", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteTransactionTransactionDelete {
  final String id;
  DeleteTransactionTransactionDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteTransactionTransactionDelete otherTyped = other as DeleteTransactionTransactionDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteTransactionTransactionDelete({
    required this.id,
  });
}

@immutable
class DeleteTransactionData {
  final DeleteTransactionTransactionDelete? transaction_delete;
  DeleteTransactionData.fromJson(dynamic json):
  
  transaction_delete = json['transaction_delete'] == null ? null : DeleteTransactionTransactionDelete.fromJson(json['transaction_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteTransactionData otherTyped = other as DeleteTransactionData;
    return transaction_delete == otherTyped.transaction_delete;
    
  }
  @override
  int get hashCode => transaction_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (transaction_delete != null) {
      json['transaction_delete'] = transaction_delete!.toJson();
    }
    return json;
  }

  DeleteTransactionData({
    this.transaction_delete,
  });
}

@immutable
class DeleteTransactionVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteTransactionVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteTransactionVariables otherTyped = other as DeleteTransactionVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteTransactionVariables({
    required this.id,
  });
}

