part of 'generated.dart';

class UpdateMemberProfileVariablesBuilder {
  String fullName;

  final FirebaseDataConnect _dataConnect;
  UpdateMemberProfileVariablesBuilder(this._dataConnect, {required  this.fullName,});
  Deserializer<UpdateMemberProfileData> dataDeserializer = (dynamic json)  => UpdateMemberProfileData.fromJson(jsonDecode(json));
  Serializer<UpdateMemberProfileVariables> varsSerializer = (UpdateMemberProfileVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateMemberProfileData, UpdateMemberProfileVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateMemberProfileData, UpdateMemberProfileVariables> ref() {
    UpdateMemberProfileVariables vars= UpdateMemberProfileVariables(fullName: fullName,);
    return _dataConnect.mutation("UpdateMemberProfile", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateMemberProfileMemberUpdate {
  final String id;
  UpdateMemberProfileMemberUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMemberProfileMemberUpdate otherTyped = other as UpdateMemberProfileMemberUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateMemberProfileMemberUpdate({
    required this.id,
  });
}

@immutable
class UpdateMemberProfileData {
  final UpdateMemberProfileMemberUpdate? member_update;
  UpdateMemberProfileData.fromJson(dynamic json):
  
  member_update = json['member_update'] == null ? null : UpdateMemberProfileMemberUpdate.fromJson(json['member_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMemberProfileData otherTyped = other as UpdateMemberProfileData;
    return member_update == otherTyped.member_update;
    
  }
  @override
  int get hashCode => member_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (member_update != null) {
      json['member_update'] = member_update!.toJson();
    }
    return json;
  }

  UpdateMemberProfileData({
    this.member_update,
  });
}

@immutable
class UpdateMemberProfileVariables {
  final String fullName;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateMemberProfileVariables.fromJson(Map<String, dynamic> json):
  
  fullName = nativeFromJson<String>(json['fullName']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMemberProfileVariables otherTyped = other as UpdateMemberProfileVariables;
    return fullName == otherTyped.fullName;
    
  }
  @override
  int get hashCode => fullName.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['fullName'] = nativeToJson<String>(fullName);
    return json;
  }

  UpdateMemberProfileVariables({
    required this.fullName,
  });
}

