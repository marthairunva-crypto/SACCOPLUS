part of 'generated.dart';

class AddRepaymentVariablesBuilder {
  String loanId;
  double amount;

  final FirebaseDataConnect _dataConnect;
  AddRepaymentVariablesBuilder(this._dataConnect, {required  this.loanId,required  this.amount,});
  Deserializer<AddRepaymentData> dataDeserializer = (dynamic json)  => AddRepaymentData.fromJson(jsonDecode(json));
  Serializer<AddRepaymentVariables> varsSerializer = (AddRepaymentVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AddRepaymentData, AddRepaymentVariables>> execute() {
    return ref().execute();
  }

  MutationRef<AddRepaymentData, AddRepaymentVariables> ref() {
    AddRepaymentVariables vars= AddRepaymentVariables(loanId: loanId,amount: amount,);
    return _dataConnect.mutation("AddRepayment", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class AddRepaymentLoanRepaymentInsert {
  final String id;
  AddRepaymentLoanRepaymentInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddRepaymentLoanRepaymentInsert otherTyped = other as AddRepaymentLoanRepaymentInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  AddRepaymentLoanRepaymentInsert({
    required this.id,
  });
}

@immutable
class AddRepaymentData {
  final AddRepaymentLoanRepaymentInsert loanRepayment_insert;
  AddRepaymentData.fromJson(dynamic json):
  
  loanRepayment_insert = AddRepaymentLoanRepaymentInsert.fromJson(json['loanRepayment_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddRepaymentData otherTyped = other as AddRepaymentData;
    return loanRepayment_insert == otherTyped.loanRepayment_insert;
    
  }
  @override
  int get hashCode => loanRepayment_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['loanRepayment_insert'] = loanRepayment_insert.toJson();
    return json;
  }

  AddRepaymentData({
    required this.loanRepayment_insert,
  });
}

@immutable
class AddRepaymentVariables {
  final String loanId;
  final double amount;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  AddRepaymentVariables.fromJson(Map<String, dynamic> json):
  
  loanId = nativeFromJson<String>(json['loanId']),
  amount = nativeFromJson<double>(json['amount']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddRepaymentVariables otherTyped = other as AddRepaymentVariables;
    return loanId == otherTyped.loanId && 
    amount == otherTyped.amount;
    
  }
  @override
  int get hashCode => Object.hashAll([loanId.hashCode, amount.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['loanId'] = nativeToJson<String>(loanId);
    json['amount'] = nativeToJson<double>(amount);
    return json;
  }

  AddRepaymentVariables({
    required this.loanId,
    required this.amount,
  });
}

