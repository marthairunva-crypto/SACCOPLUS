part of 'generated.dart';

class GetMyProfileVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  GetMyProfileVariablesBuilder(this._dataConnect, );
  Deserializer<GetMyProfileData> dataDeserializer = (dynamic json)  => GetMyProfileData.fromJson(jsonDecode(json));
  
  Future<QueryResult<GetMyProfileData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetMyProfileData, void> ref() {
    
    return _dataConnect.query("GetMyProfile", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class GetMyProfileMember {
  final String fullName;
  final String email;
  final String status;
  GetMyProfileMember.fromJson(dynamic json):
  
  fullName = nativeFromJson<String>(json['fullName']),
  email = nativeFromJson<String>(json['email']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMyProfileMember otherTyped = other as GetMyProfileMember;
    return fullName == otherTyped.fullName && 
    email == otherTyped.email && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([fullName.hashCode, email.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['fullName'] = nativeToJson<String>(fullName);
    json['email'] = nativeToJson<String>(email);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  GetMyProfileMember({
    required this.fullName,
    required this.email,
    required this.status,
  });
}

@immutable
class GetMyProfileData {
  final GetMyProfileMember? member;
  GetMyProfileData.fromJson(dynamic json):
  
  member = json['member'] == null ? null : GetMyProfileMember.fromJson(json['member']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMyProfileData otherTyped = other as GetMyProfileData;
    return member == otherTyped.member;
    
  }
  @override
  int get hashCode => member.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (member != null) {
      json['member'] = member!.toJson();
    }
    return json;
  }

  GetMyProfileData({
    this.member,
  });
}

