# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### GetMyProfile
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.getMyProfile().execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetMyProfileData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getMyProfile();
GetMyProfileData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.getMyProfile().ref();
ref.execute();

ref.subscribe(...);
```


### ListMyAccounts
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listMyAccounts().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMyAccountsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listMyAccounts();
ListMyAccountsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listMyAccounts().ref();
ref.execute();

ref.subscribe(...);
```


### GetLoanDetails
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getLoanDetails(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetLoanDetailsData, GetLoanDetailsVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getLoanDetails(
  id: id,
);
GetLoanDetailsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getLoanDetails(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListLoanRepayments
#### Required Arguments
```dart
String loanId = ...;
ExampleConnector.instance.listLoanRepayments(
  loanId: loanId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListLoanRepaymentsData, ListLoanRepaymentsVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listLoanRepayments(
  loanId: loanId,
);
ListLoanRepaymentsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String loanId = ...;

final ref = ExampleConnector.instance.listLoanRepayments(
  loanId: loanId,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListMyTransactions
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listMyTransactions().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMyTransactionsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listMyTransactions();
ListMyTransactionsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listMyTransactions().ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateMemberData
#### Required Arguments
```dart
String fullName = ...;
String email = ...;
String phone = ...;
ExampleConnector.instance.createMemberData(
  fullName: fullName,
  email: email,
  phone: phone,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateMemberDataData, CreateMemberDataVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createMemberData(
  fullName: fullName,
  email: email,
  phone: phone,
);
CreateMemberDataData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String fullName = ...;
String email = ...;
String phone = ...;

final ref = ExampleConnector.instance.createMemberData(
  fullName: fullName,
  email: email,
  phone: phone,
).ref();
ref.execute();
```


### UpdateMemberProfile
#### Required Arguments
```dart
String fullName = ...;
ExampleConnector.instance.updateMemberProfile(
  fullName: fullName,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateMemberProfileData, UpdateMemberProfileVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateMemberProfile(
  fullName: fullName,
);
UpdateMemberProfileData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String fullName = ...;

final ref = ExampleConnector.instance.updateMemberProfile(
  fullName: fullName,
).ref();
ref.execute();
```


### DeleteMember
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.deleteMember().execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteMemberData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteMember();
DeleteMemberData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.deleteMember().ref();
ref.execute();
```


### CreateAccount
#### Required Arguments
```dart
double totalSavings = ...;
ExampleConnector.instance.createAccount(
  totalSavings: totalSavings,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateAccountData, CreateAccountVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createAccount(
  totalSavings: totalSavings,
);
CreateAccountData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
double totalSavings = ...;

final ref = ExampleConnector.instance.createAccount(
  totalSavings: totalSavings,
).ref();
ref.execute();
```


### UpdateAccountSavings
#### Required Arguments
```dart
String id = ...;
double totalSavings = ...;
ExampleConnector.instance.updateAccountSavings(
  id: id,
  totalSavings: totalSavings,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateAccountSavingsData, UpdateAccountSavingsVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateAccountSavings(
  id: id,
  totalSavings: totalSavings,
);
UpdateAccountSavingsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
double totalSavings = ...;

final ref = ExampleConnector.instance.updateAccountSavings(
  id: id,
  totalSavings: totalSavings,
).ref();
ref.execute();
```


### DeleteAccount
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteAccount(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteAccountData, DeleteAccountVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteAccount(
  id: id,
);
DeleteAccountData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteAccount(
  id: id,
).ref();
ref.execute();
```


### CreateLoan
#### Required Arguments
```dart
double principal = ...;
double interest = ...;
DateTime dueDate = ...;
ExampleConnector.instance.createLoan(
  principal: principal,
  interest: interest,
  dueDate: dueDate,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateLoanData, CreateLoanVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createLoan(
  principal: principal,
  interest: interest,
  dueDate: dueDate,
);
CreateLoanData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
double principal = ...;
double interest = ...;
DateTime dueDate = ...;

final ref = ExampleConnector.instance.createLoan(
  principal: principal,
  interest: interest,
  dueDate: dueDate,
).ref();
ref.execute();
```


### UpdateLoanStatus
#### Required Arguments
```dart
String id = ...;
String status = ...;
ExampleConnector.instance.updateLoanStatus(
  id: id,
  status: status,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateLoanStatusData, UpdateLoanStatusVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateLoanStatus(
  id: id,
  status: status,
);
UpdateLoanStatusData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
String status = ...;

final ref = ExampleConnector.instance.updateLoanStatus(
  id: id,
  status: status,
).ref();
ref.execute();
```


### DeleteLoan
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteLoan(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteLoanData, DeleteLoanVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteLoan(
  id: id,
);
DeleteLoanData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteLoan(
  id: id,
).ref();
ref.execute();
```


### AddRepayment
#### Required Arguments
```dart
String loanId = ...;
double amount = ...;
ExampleConnector.instance.addRepayment(
  loanId: loanId,
  amount: amount,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<AddRepaymentData, AddRepaymentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.addRepayment(
  loanId: loanId,
  amount: amount,
);
AddRepaymentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String loanId = ...;
double amount = ...;

final ref = ExampleConnector.instance.addRepayment(
  loanId: loanId,
  amount: amount,
).ref();
ref.execute();
```


### UpdateRepayment
#### Required Arguments
```dart
String id = ...;
double amount = ...;
ExampleConnector.instance.updateRepayment(
  id: id,
  amount: amount,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateRepaymentData, UpdateRepaymentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateRepayment(
  id: id,
  amount: amount,
);
UpdateRepaymentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
double amount = ...;

final ref = ExampleConnector.instance.updateRepayment(
  id: id,
  amount: amount,
).ref();
ref.execute();
```


### DeleteRepayment
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteRepayment(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteRepaymentData, DeleteRepaymentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteRepayment(
  id: id,
);
DeleteRepaymentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteRepayment(
  id: id,
).ref();
ref.execute();
```


### RecordTransaction
#### Required Arguments
```dart
double amount = ...;
String type = ...;
ExampleConnector.instance.recordTransaction(
  amount: amount,
  type: type,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<RecordTransactionData, RecordTransactionVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.recordTransaction(
  amount: amount,
  type: type,
);
RecordTransactionData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
double amount = ...;
String type = ...;

final ref = ExampleConnector.instance.recordTransaction(
  amount: amount,
  type: type,
).ref();
ref.execute();
```


### UpdateTransactionNotes
#### Required Arguments
```dart
String id = ...;
String notes = ...;
ExampleConnector.instance.updateTransactionNotes(
  id: id,
  notes: notes,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateTransactionNotesData, UpdateTransactionNotesVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateTransactionNotes(
  id: id,
  notes: notes,
);
UpdateTransactionNotesData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
String notes = ...;

final ref = ExampleConnector.instance.updateTransactionNotes(
  id: id,
  notes: notes,
).ref();
ref.execute();
```


### DeleteTransaction
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteTransaction(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteTransactionData, DeleteTransactionVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteTransaction(
  id: id,
);
DeleteTransactionData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteTransaction(
  id: id,
).ref();
ref.execute();
```

