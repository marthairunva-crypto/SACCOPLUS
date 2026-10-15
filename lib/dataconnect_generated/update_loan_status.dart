part of 'generated.dart';

class UpdateLoanStatusVariablesBuilder {
  String id;
  String status;

  final FirebaseDataConnect _dataConnect;
  UpdateLoanStatusVariablesBuilder(this._dataConnect, {required  this.id,required  this.status,});
  Deserializer<UpdateLoanStatusData> dataDeserializer = (dynamic json)  => UpdateLoanStatusData.fromJson(jsonDecode(json));
  Serializer<UpdateLoanStatusVariables> varsSerializer = (UpdateLoanStatusVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateLoanStatusData, UpdateLoanStatusVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateLoanStatusData, UpdateLoanStatusVariables> ref() {
    UpdateLoanStatusVariables vars= UpdateLoanStatusVariables(id: id,status: status,);
    return _dataConnect.mutation("UpdateLoanStatus", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateLoanStatusLoanUpdate {
  final String id;
  UpdateLoanStatusLoanUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateLoanStatusLoanUpdate otherTyped = other as UpdateLoanStatusLoanUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateLoanStatusLoanUpdate({
    required this.id,
  });
}

@immutable
class UpdateLoanStatusData {
  final UpdateLoanStatusLoanUpdate? loan_update;
  UpdateLoanStatusData.fromJson(dynamic json):
  
  loan_update = json['loan_update'] == null ? null : UpdateLoanStatusLoanUpdate.fromJson(json['loan_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateLoanStatusData otherTyped = other as UpdateLoanStatusData;
    return loan_update == otherTyped.loan_update;
    
  }
  @override
  int get hashCode => loan_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (loan_update != null) {
      json['loan_update'] = loan_update!.toJson();
    }
    return json;
  }

  UpdateLoanStatusData({
    this.loan_update,
  });
}

@immutable
class UpdateLoanStatusVariables {
  final String id;
  final String status;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateLoanStatusVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateLoanStatusVariables otherTyped = other as UpdateLoanStatusVariables;
    return id == otherTyped.id && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  UpdateLoanStatusVariables({
    required this.id,
    required this.status,
  });
}

