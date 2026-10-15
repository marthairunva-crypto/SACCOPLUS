part of 'generated.dart';

class UpdateAccountSavingsVariablesBuilder {
  String id;
  double totalSavings;

  final FirebaseDataConnect _dataConnect;
  UpdateAccountSavingsVariablesBuilder(this._dataConnect, {required  this.id,required  this.totalSavings,});
  Deserializer<UpdateAccountSavingsData> dataDeserializer = (dynamic json)  => UpdateAccountSavingsData.fromJson(jsonDecode(json));
  Serializer<UpdateAccountSavingsVariables> varsSerializer = (UpdateAccountSavingsVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateAccountSavingsData, UpdateAccountSavingsVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateAccountSavingsData, UpdateAccountSavingsVariables> ref() {
    UpdateAccountSavingsVariables vars= UpdateAccountSavingsVariables(id: id,totalSavings: totalSavings,);
    return _dataConnect.mutation("UpdateAccountSavings", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateAccountSavingsAccountUpdate {
  final String id;
  UpdateAccountSavingsAccountUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateAccountSavingsAccountUpdate otherTyped = other as UpdateAccountSavingsAccountUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateAccountSavingsAccountUpdate({
    required this.id,
  });
}

@immutable
class UpdateAccountSavingsData {
  final UpdateAccountSavingsAccountUpdate? account_update;
  UpdateAccountSavingsData.fromJson(dynamic json):
  
  account_update = json['account_update'] == null ? null : UpdateAccountSavingsAccountUpdate.fromJson(json['account_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateAccountSavingsData otherTyped = other as UpdateAccountSavingsData;
    return account_update == otherTyped.account_update;
    
  }
  @override
  int get hashCode => account_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (account_update != null) {
      json['account_update'] = account_update!.toJson();
    }
    return json;
  }

  UpdateAccountSavingsData({
    this.account_update,
  });
}

@immutable
class UpdateAccountSavingsVariables {
  final String id;
  final double totalSavings;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateAccountSavingsVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  totalSavings = nativeFromJson<double>(json['totalSavings']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateAccountSavingsVariables otherTyped = other as UpdateAccountSavingsVariables;
    return id == otherTyped.id && 
    totalSavings == otherTyped.totalSavings;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, totalSavings.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['totalSavings'] = nativeToJson<double>(totalSavings);
    return json;
  }

  UpdateAccountSavingsVariables({
    required this.id,
    required this.totalSavings,
  });
}

