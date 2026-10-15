part of 'generated.dart';

class UpdateRepaymentVariablesBuilder {
  String id;
  double amount;

  final FirebaseDataConnect _dataConnect;
  UpdateRepaymentVariablesBuilder(this._dataConnect, {required  this.id,required  this.amount,});
  Deserializer<UpdateRepaymentData> dataDeserializer = (dynamic json)  => UpdateRepaymentData.fromJson(jsonDecode(json));
  Serializer<UpdateRepaymentVariables> varsSerializer = (UpdateRepaymentVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateRepaymentData, UpdateRepaymentVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateRepaymentData, UpdateRepaymentVariables> ref() {
    UpdateRepaymentVariables vars= UpdateRepaymentVariables(id: id,amount: amount,);
    return _dataConnect.mutation("UpdateRepayment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateRepaymentLoanRepaymentUpdate {
  final String id;
  UpdateRepaymentLoanRepaymentUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateRepaymentLoanRepaymentUpdate otherTyped = other as UpdateRepaymentLoanRepaymentUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateRepaymentLoanRepaymentUpdate({
    required this.id,
  });
}

@immutable
class UpdateRepaymentData {
  final UpdateRepaymentLoanRepaymentUpdate? loanRepayment_update;
  UpdateRepaymentData.fromJson(dynamic json):
  
  loanRepayment_update = json['loanRepayment_update'] == null ? null : UpdateRepaymentLoanRepaymentUpdate.fromJson(json['loanRepayment_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateRepaymentData otherTyped = other as UpdateRepaymentData;
    return loanRepayment_update == otherTyped.loanRepayment_update;
    
  }
  @override
  int get hashCode => loanRepayment_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (loanRepayment_update != null) {
      json['loanRepayment_update'] = loanRepayment_update!.toJson();
    }
    return json;
  }

  UpdateRepaymentData({
    this.loanRepayment_update,
  });
}

@immutable
class UpdateRepaymentVariables {
  final String id;
  final double amount;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateRepaymentVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  amount = nativeFromJson<double>(json['amount']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateRepaymentVariables otherTyped = other as UpdateRepaymentVariables;
    return id == otherTyped.id && 
    amount == otherTyped.amount;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, amount.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['amount'] = nativeToJson<double>(amount);
    return json;
  }

  UpdateRepaymentVariables({
    required this.id,
    required this.amount,
  });
}

