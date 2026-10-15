part of 'generated.dart';

class CreateAccountVariablesBuilder {
  double totalSavings;

  final FirebaseDataConnect _dataConnect;
  CreateAccountVariablesBuilder(this._dataConnect, {required  this.totalSavings,});
  Deserializer<CreateAccountData> dataDeserializer = (dynamic json)  => CreateAccountData.fromJson(jsonDecode(json));
  Serializer<CreateAccountVariables> varsSerializer = (CreateAccountVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateAccountData, CreateAccountVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateAccountData, CreateAccountVariables> ref() {
    CreateAccountVariables vars= CreateAccountVariables(totalSavings: totalSavings,);
    return _dataConnect.mutation("CreateAccount", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateAccountAccountInsert {
  final String id;
  CreateAccountAccountInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateAccountAccountInsert otherTyped = other as CreateAccountAccountInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateAccountAccountInsert({
    required this.id,
  });
}

@immutable
class CreateAccountData {
  final CreateAccountAccountInsert account_insert;
  CreateAccountData.fromJson(dynamic json):
  
  account_insert = CreateAccountAccountInsert.fromJson(json['account_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateAccountData otherTyped = other as CreateAccountData;
    return account_insert == otherTyped.account_insert;
    
  }
  @override
  int get hashCode => account_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['account_insert'] = account_insert.toJson();
    return json;
  }

  CreateAccountData({
    required this.account_insert,
  });
}

@immutable
class CreateAccountVariables {
  final double totalSavings;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateAccountVariables.fromJson(Map<String, dynamic> json):
  
  totalSavings = nativeFromJson<double>(json['totalSavings']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateAccountVariables otherTyped = other as CreateAccountVariables;
    return totalSavings == otherTyped.totalSavings;
    
  }
  @override
  int get hashCode => totalSavings.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['totalSavings'] = nativeToJson<double>(totalSavings);
    return json;
  }

  CreateAccountVariables({
    required this.totalSavings,
  });
}

