part of 'generated.dart';

class UpdateTransactionNotesVariablesBuilder {
  String id;
  String notes;

  final FirebaseDataConnect _dataConnect;
  UpdateTransactionNotesVariablesBuilder(this._dataConnect, {required  this.id,required  this.notes,});
  Deserializer<UpdateTransactionNotesData> dataDeserializer = (dynamic json)  => UpdateTransactionNotesData.fromJson(jsonDecode(json));
  Serializer<UpdateTransactionNotesVariables> varsSerializer = (UpdateTransactionNotesVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateTransactionNotesData, UpdateTransactionNotesVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateTransactionNotesData, UpdateTransactionNotesVariables> ref() {
    UpdateTransactionNotesVariables vars= UpdateTransactionNotesVariables(id: id,notes: notes,);
    return _dataConnect.mutation("UpdateTransactionNotes", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateTransactionNotesTransactionUpdate {
  final String id;
  UpdateTransactionNotesTransactionUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateTransactionNotesTransactionUpdate otherTyped = other as UpdateTransactionNotesTransactionUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateTransactionNotesTransactionUpdate({
    required this.id,
  });
}

@immutable
class UpdateTransactionNotesData {
  final UpdateTransactionNotesTransactionUpdate? transaction_update;
  UpdateTransactionNotesData.fromJson(dynamic json):
  
  transaction_update = json['transaction_update'] == null ? null : UpdateTransactionNotesTransactionUpdate.fromJson(json['transaction_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateTransactionNotesData otherTyped = other as UpdateTransactionNotesData;
    return transaction_update == otherTyped.transaction_update;
    
  }
  @override
  int get hashCode => transaction_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (transaction_update != null) {
      json['transaction_update'] = transaction_update!.toJson();
    }
    return json;
  }

  UpdateTransactionNotesData({
    this.transaction_update,
  });
}

@immutable
class UpdateTransactionNotesVariables {
  final String id;
  final String notes;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateTransactionNotesVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  notes = nativeFromJson<String>(json['notes']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateTransactionNotesVariables otherTyped = other as UpdateTransactionNotesVariables;
    return id == otherTyped.id && 
    notes == otherTyped.notes;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, notes.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['notes'] = nativeToJson<String>(notes);
    return json;
  }

  UpdateTransactionNotesVariables({
    required this.id,
    required this.notes,
  });
}

