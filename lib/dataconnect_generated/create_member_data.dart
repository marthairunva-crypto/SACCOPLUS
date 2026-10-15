part of 'generated.dart';

class CreateMemberDataVariablesBuilder {
  String fullName;
  String email;
  String phone;

  final FirebaseDataConnect _dataConnect;
  CreateMemberDataVariablesBuilder(this._dataConnect, {required  this.fullName,required  this.email,required  this.phone,});
  Deserializer<CreateMemberDataData> dataDeserializer = (dynamic json)  => CreateMemberDataData.fromJson(jsonDecode(json));
  Serializer<CreateMemberDataVariables> varsSerializer = (CreateMemberDataVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateMemberDataData, CreateMemberDataVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateMemberDataData, CreateMemberDataVariables> ref() {
    CreateMemberDataVariables vars= CreateMemberDataVariables(fullName: fullName,email: email,phone: phone,);
    return _dataConnect.mutation("CreateMemberData", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateMemberDataMemberInsert {
  final String id;
  CreateMemberDataMemberInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMemberDataMemberInsert otherTyped = other as CreateMemberDataMemberInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateMemberDataMemberInsert({
    required this.id,
  });
}

@immutable
class CreateMemberDataData {
  final CreateMemberDataMemberInsert member_insert;
  CreateMemberDataData.fromJson(dynamic json):
  
  member_insert = CreateMemberDataMemberInsert.fromJson(json['member_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMemberDataData otherTyped = other as CreateMemberDataData;
    return member_insert == otherTyped.member_insert;
    
  }
  @override
  int get hashCode => member_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['member_insert'] = member_insert.toJson();
    return json;
  }

  CreateMemberDataData({
    required this.member_insert,
  });
}

@immutable
class CreateMemberDataVariables {
  final String fullName;
  final String email;
  final String phone;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateMemberDataVariables.fromJson(Map<String, dynamic> json):
  
  fullName = nativeFromJson<String>(json['fullName']),
  email = nativeFromJson<String>(json['email']),
  phone = nativeFromJson<String>(json['phone']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMemberDataVariables otherTyped = other as CreateMemberDataVariables;
    return fullName == otherTyped.fullName && 
    email == otherTyped.email && 
    phone == otherTyped.phone;
    
  }
  @override
  int get hashCode => Object.hashAll([fullName.hashCode, email.hashCode, phone.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['fullName'] = nativeToJson<String>(fullName);
    json['email'] = nativeToJson<String>(email);
    json['phone'] = nativeToJson<String>(phone);
    return json;
  }

  CreateMemberDataVariables({
    required this.fullName,
    required this.email,
    required this.phone,
  });
}

