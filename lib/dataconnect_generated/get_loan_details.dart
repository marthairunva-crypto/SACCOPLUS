part of 'generated.dart';

class GetLoanDetailsVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetLoanDetailsVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetLoanDetailsData> dataDeserializer = (dynamic json)  => GetLoanDetailsData.fromJson(jsonDecode(json));
  Serializer<GetLoanDetailsVariables> varsSerializer = (GetLoanDetailsVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetLoanDetailsData, GetLoanDetailsVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetLoanDetailsData, GetLoanDetailsVariables> ref() {
    GetLoanDetailsVariables vars= GetLoanDetailsVariables(id: id,);
    return _dataConnect.query("GetLoanDetails", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetLoanDetailsLoan {
  final double principalAmount;
  final String status;
  final DateTime dueDate;
  GetLoanDetailsLoan.fromJson(dynamic json):
  
  principalAmount = nativeFromJson<double>(json['principalAmount']),
  status = nativeFromJson<String>(json['status']),
  dueDate = nativeFromJson<DateTime>(json['dueDate']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetLoanDetailsLoan otherTyped = other as GetLoanDetailsLoan;
    return principalAmount == otherTyped.principalAmount && 
    status == otherTyped.status && 
    dueDate == otherTyped.dueDate;
    
  }
  @override
  int get hashCode => Object.hashAll([principalAmount.hashCode, status.hashCode, dueDate.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['principalAmount'] = nativeToJson<double>(principalAmount);
    json['status'] = nativeToJson<String>(status);
    json['dueDate'] = nativeToJson<DateTime>(dueDate);
    return json;
  }

  GetLoanDetailsLoan({
    required this.principalAmount,
    required this.status,
    required this.dueDate,
  });
}

@immutable
class GetLoanDetailsData {
  final GetLoanDetailsLoan? loan;
  GetLoanDetailsData.fromJson(dynamic json):
  
  loan = json['loan'] == null ? null : GetLoanDetailsLoan.fromJson(json['loan']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetLoanDetailsData otherTyped = other as GetLoanDetailsData;
    return loan == otherTyped.loan;
    
  }
  @override
  int get hashCode => loan.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (loan != null) {
      json['loan'] = loan!.toJson();
    }
    return json;
  }

  GetLoanDetailsData({
    this.loan,
  });
}

@immutable
class GetLoanDetailsVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetLoanDetailsVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetLoanDetailsVariables otherTyped = other as GetLoanDetailsVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetLoanDetailsVariables({
    required this.id,
  });
}

