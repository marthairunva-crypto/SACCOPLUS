part of 'generated.dart';

class RecordTransactionVariablesBuilder {
  double amount;
  String type;

  final FirebaseDataConnect _dataConnect;
  RecordTransactionVariablesBuilder(this._dataConnect, {required  this.amount,required  this.type,});
  Deserializer<RecordTransactionData> dataDeserializer = (dynamic json)  => RecordTransactionData.fromJson(jsonDecode(json));
  Serializer<RecordTransactionVariables> varsSerializer = (RecordTransactionVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<RecordTransactionData, RecordTransactionVariables>> execute() {
    return ref().execute();
  }

  MutationRef<RecordTransactionData, RecordTransactionVariables> ref() {
    RecordTransactionVariables vars= RecordTransactionVariables(amount: amount,type: type,);
    return _dataConnect.mutation("RecordTransaction", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class RecordTransactionTransactionInsert {
  final String id;
  RecordTransactionTransactionInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final RecordTransactionTransactionInsert otherTyped = other as RecordTransactionTransactionInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  RecordTransactionTransactionInsert({
    required this.id,
  });
}

@immutable
class RecordTransactionData {
  final RecordTransactionTransactionInsert transaction_insert;
  RecordTransactionData.fromJson(dynamic json):
  
  transaction_insert = RecordTransactionTransactionInsert.fromJson(json['transaction_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final RecordTransactionData otherTyped = other as RecordTransactionData;
    return transaction_insert == otherTyped.transaction_insert;
    
  }
  @override
  int get hashCode => transaction_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['transaction_insert'] = transaction_insert.toJson();
    return json;
  }

  RecordTransactionData({
    required this.transaction_insert,
  });
}

@immutable
class RecordTransactionVariables {
  final double amount;
  final String type;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  RecordTransactionVariables.fromJson(Map<String, dynamic> json):
  
  amount = nativeFromJson<double>(json['amount']),
  type = nativeFromJson<String>(json['type']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final RecordTransactionVariables otherTyped = other as RecordTransactionVariables;
    return amount == otherTyped.amount && 
    type == otherTyped.type;
    
  }
  @override
  int get hashCode => Object.hashAll([amount.hashCode, type.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['amount'] = nativeToJson<double>(amount);
    json['type'] = nativeToJson<String>(type);
    return json;
  }

  RecordTransactionVariables({
    required this.amount,
    required this.type,
  });
}

