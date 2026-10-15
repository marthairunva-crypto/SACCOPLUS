part of 'generated.dart';

class DeleteMemberVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  DeleteMemberVariablesBuilder(this._dataConnect, );
  Deserializer<DeleteMemberData> dataDeserializer = (dynamic json)  => DeleteMemberData.fromJson(jsonDecode(json));
  
  Future<OperationResult<DeleteMemberData, void>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteMemberData, void> ref() {
    
    return _dataConnect.mutation("DeleteMember", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class DeleteMemberMemberDelete {
  final String id;
  DeleteMemberMemberDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMemberMemberDelete otherTyped = other as DeleteMemberMemberDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteMemberMemberDelete({
    required this.id,
  });
}

@immutable
class DeleteMemberData {
  final DeleteMemberMemberDelete? member_delete;
  DeleteMemberData.fromJson(dynamic json):
  
  member_delete = json['member_delete'] == null ? null : DeleteMemberMemberDelete.fromJson(json['member_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMemberData otherTyped = other as DeleteMemberData;
    return member_delete == otherTyped.member_delete;
    
  }
  @override
  int get hashCode => member_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (member_delete != null) {
      json['member_delete'] = member_delete!.toJson();
    }
    return json;
  }

  DeleteMemberData({
    this.member_delete,
  });
}

