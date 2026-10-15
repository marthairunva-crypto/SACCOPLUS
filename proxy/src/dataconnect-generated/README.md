# Generated TypeScript README
This README will guide you through the process of using the generated JavaScript SDK package for the connector `example`. It will also provide examples on how to use your generated SDK to call your Data Connect queries and mutations.

***NOTE:** This README is generated alongside the generated SDK. If you make changes to this file, they will be overwritten when the SDK is regenerated.*

# Table of Contents
- [**Overview**](#generated-javascript-readme)
- [**Accessing the connector**](#accessing-the-connector)
  - [*Connecting to the local Emulator*](#connecting-to-the-local-emulator)
- [**Queries**](#queries)
  - [*GetMyProfile*](#getmyprofile)
  - [*ListMyAccounts*](#listmyaccounts)
  - [*GetLoanDetails*](#getloandetails)
  - [*ListLoanRepayments*](#listloanrepayments)
  - [*ListMyTransactions*](#listmytransactions)
- [**Mutations**](#mutations)
  - [*CreateMemberData*](#creatememberdata)
  - [*UpdateMemberProfile*](#updatememberprofile)
  - [*DeleteMember*](#deletemember)
  - [*CreateAccount*](#createaccount)
  - [*UpdateAccountSavings*](#updateaccountsavings)
  - [*DeleteAccount*](#deleteaccount)
  - [*CreateLoan*](#createloan)
  - [*UpdateLoanStatus*](#updateloanstatus)
  - [*DeleteLoan*](#deleteloan)
  - [*AddRepayment*](#addrepayment)
  - [*UpdateRepayment*](#updaterepayment)
  - [*DeleteRepayment*](#deleterepayment)
  - [*RecordTransaction*](#recordtransaction)
  - [*UpdateTransactionNotes*](#updatetransactionnotes)
  - [*DeleteTransaction*](#deletetransaction)

# Accessing the connector
A connector is a collection of Queries and Mutations. One SDK is generated for each connector - this SDK is generated for the connector `example`. You can find more information about connectors in the [Data Connect documentation](https://firebase.google.com/docs/data-connect#how-does).

You can use this generated SDK by importing from the package `@dataconnect/generated` as shown below. Both CommonJS and ESM imports are supported.

You can also follow the instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#set-client).

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
```

## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code.
You can also follow the emulator instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#instrument-clients).

```typescript
import { connectDataConnectEmulator, getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
connectDataConnectEmulator(dataConnect, 'localhost', 9399);
```

After it's initialized, you can call your Data Connect [queries](#queries) and [mutations](#mutations) from your generated SDK.

# Queries

There are two ways to execute a Data Connect Query using the generated Web SDK:
- Using a Query Reference function, which returns a `QueryRef`
  - The `QueryRef` can be used as an argument to `executeQuery()`, which will execute the Query and return a `QueryPromise`
- Using an action shortcut function, which returns a `QueryPromise`
  - Calling the action shortcut function will execute the Query and return a `QueryPromise`

The following is true for both the action shortcut function and the `QueryRef` function:
- The `QueryPromise` returned will resolve to the result of the Query once it has finished executing
- If the Query accepts arguments, both the action shortcut function and the `QueryRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Query
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `example` connector's generated functions to execute each query. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-queries).

## GetMyProfile
You can execute the `GetMyProfile` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getMyProfile(options?: ExecuteQueryOptions): QueryPromise<GetMyProfileData, undefined>;

interface GetMyProfileRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<GetMyProfileData, undefined>;
}
export const getMyProfileRef: GetMyProfileRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getMyProfile(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<GetMyProfileData, undefined>;

interface GetMyProfileRef {
  ...
  (dc: DataConnect): QueryRef<GetMyProfileData, undefined>;
}
export const getMyProfileRef: GetMyProfileRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getMyProfileRef:
```typescript
const name = getMyProfileRef.operationName;
console.log(name);
```

### Variables
The `GetMyProfile` query has no variables.
### Return Type
Recall that executing the `GetMyProfile` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetMyProfileData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface GetMyProfileData {
  member?: {
    fullName: string;
    email: string;
    status: string;
  };
}
```
### Using `GetMyProfile`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getMyProfile } from '@dataconnect/generated';


// Call the `getMyProfile()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getMyProfile();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getMyProfile(dataConnect);

console.log(data.member);

// Or, you can use the `Promise` API.
getMyProfile().then((response) => {
  const data = response.data;
  console.log(data.member);
});
```

### Using `GetMyProfile`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getMyProfileRef } from '@dataconnect/generated';


// Call the `getMyProfileRef()` function to get a reference to the query.
const ref = getMyProfileRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getMyProfileRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.member);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.member);
});
```

## ListMyAccounts
You can execute the `ListMyAccounts` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listMyAccounts(options?: ExecuteQueryOptions): QueryPromise<ListMyAccountsData, undefined>;

interface ListMyAccountsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListMyAccountsData, undefined>;
}
export const listMyAccountsRef: ListMyAccountsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listMyAccounts(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListMyAccountsData, undefined>;

interface ListMyAccountsRef {
  ...
  (dc: DataConnect): QueryRef<ListMyAccountsData, undefined>;
}
export const listMyAccountsRef: ListMyAccountsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listMyAccountsRef:
```typescript
const name = listMyAccountsRef.operationName;
console.log(name);
```

### Variables
The `ListMyAccounts` query has no variables.
### Return Type
Recall that executing the `ListMyAccounts` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListMyAccountsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListMyAccountsData {
  accounts: ({
    id: UUIDString;
    totalSavings: number;
    outstandingLoans: number;
  } & Account_Key)[];
}
```
### Using `ListMyAccounts`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listMyAccounts } from '@dataconnect/generated';


// Call the `listMyAccounts()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listMyAccounts();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listMyAccounts(dataConnect);

console.log(data.accounts);

// Or, you can use the `Promise` API.
listMyAccounts().then((response) => {
  const data = response.data;
  console.log(data.accounts);
});
```

### Using `ListMyAccounts`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listMyAccountsRef } from '@dataconnect/generated';


// Call the `listMyAccountsRef()` function to get a reference to the query.
const ref = listMyAccountsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listMyAccountsRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.accounts);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.accounts);
});
```

## GetLoanDetails
You can execute the `GetLoanDetails` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getLoanDetails(vars: GetLoanDetailsVariables, options?: ExecuteQueryOptions): QueryPromise<GetLoanDetailsData, GetLoanDetailsVariables>;

interface GetLoanDetailsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetLoanDetailsVariables): QueryRef<GetLoanDetailsData, GetLoanDetailsVariables>;
}
export const getLoanDetailsRef: GetLoanDetailsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getLoanDetails(dc: DataConnect, vars: GetLoanDetailsVariables, options?: ExecuteQueryOptions): QueryPromise<GetLoanDetailsData, GetLoanDetailsVariables>;

interface GetLoanDetailsRef {
  ...
  (dc: DataConnect, vars: GetLoanDetailsVariables): QueryRef<GetLoanDetailsData, GetLoanDetailsVariables>;
}
export const getLoanDetailsRef: GetLoanDetailsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getLoanDetailsRef:
```typescript
const name = getLoanDetailsRef.operationName;
console.log(name);
```

### Variables
The `GetLoanDetails` query requires an argument of type `GetLoanDetailsVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface GetLoanDetailsVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `GetLoanDetails` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetLoanDetailsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface GetLoanDetailsData {
  loan?: {
    principalAmount: number;
    status: string;
    dueDate: DateString;
  };
}
```
### Using `GetLoanDetails`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getLoanDetails, GetLoanDetailsVariables } from '@dataconnect/generated';

// The `GetLoanDetails` query requires an argument of type `GetLoanDetailsVariables`:
const getLoanDetailsVars: GetLoanDetailsVariables = {
  id: ..., 
};

// Call the `getLoanDetails()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getLoanDetails(getLoanDetailsVars);
// Variables can be defined inline as well.
const { data } = await getLoanDetails({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getLoanDetails(dataConnect, getLoanDetailsVars);

console.log(data.loan);

// Or, you can use the `Promise` API.
getLoanDetails(getLoanDetailsVars).then((response) => {
  const data = response.data;
  console.log(data.loan);
});
```

### Using `GetLoanDetails`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getLoanDetailsRef, GetLoanDetailsVariables } from '@dataconnect/generated';

// The `GetLoanDetails` query requires an argument of type `GetLoanDetailsVariables`:
const getLoanDetailsVars: GetLoanDetailsVariables = {
  id: ..., 
};

// Call the `getLoanDetailsRef()` function to get a reference to the query.
const ref = getLoanDetailsRef(getLoanDetailsVars);
// Variables can be defined inline as well.
const ref = getLoanDetailsRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getLoanDetailsRef(dataConnect, getLoanDetailsVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.loan);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.loan);
});
```

## ListLoanRepayments
You can execute the `ListLoanRepayments` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listLoanRepayments(vars: ListLoanRepaymentsVariables, options?: ExecuteQueryOptions): QueryPromise<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;

interface ListLoanRepaymentsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: ListLoanRepaymentsVariables): QueryRef<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;
}
export const listLoanRepaymentsRef: ListLoanRepaymentsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listLoanRepayments(dc: DataConnect, vars: ListLoanRepaymentsVariables, options?: ExecuteQueryOptions): QueryPromise<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;

interface ListLoanRepaymentsRef {
  ...
  (dc: DataConnect, vars: ListLoanRepaymentsVariables): QueryRef<ListLoanRepaymentsData, ListLoanRepaymentsVariables>;
}
export const listLoanRepaymentsRef: ListLoanRepaymentsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listLoanRepaymentsRef:
```typescript
const name = listLoanRepaymentsRef.operationName;
console.log(name);
```

### Variables
The `ListLoanRepayments` query requires an argument of type `ListLoanRepaymentsVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface ListLoanRepaymentsVariables {
  loanId: UUIDString;
}
```
### Return Type
Recall that executing the `ListLoanRepayments` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListLoanRepaymentsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListLoanRepaymentsData {
  loanRepayments: ({
    amountPaid: number;
    paymentDate: TimestampString;
  })[];
}
```
### Using `ListLoanRepayments`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listLoanRepayments, ListLoanRepaymentsVariables } from '@dataconnect/generated';

// The `ListLoanRepayments` query requires an argument of type `ListLoanRepaymentsVariables`:
const listLoanRepaymentsVars: ListLoanRepaymentsVariables = {
  loanId: ..., 
};

// Call the `listLoanRepayments()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listLoanRepayments(listLoanRepaymentsVars);
// Variables can be defined inline as well.
const { data } = await listLoanRepayments({ loanId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listLoanRepayments(dataConnect, listLoanRepaymentsVars);

console.log(data.loanRepayments);

// Or, you can use the `Promise` API.
listLoanRepayments(listLoanRepaymentsVars).then((response) => {
  const data = response.data;
  console.log(data.loanRepayments);
});
```

### Using `ListLoanRepayments`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listLoanRepaymentsRef, ListLoanRepaymentsVariables } from '@dataconnect/generated';

// The `ListLoanRepayments` query requires an argument of type `ListLoanRepaymentsVariables`:
const listLoanRepaymentsVars: ListLoanRepaymentsVariables = {
  loanId: ..., 
};

// Call the `listLoanRepaymentsRef()` function to get a reference to the query.
const ref = listLoanRepaymentsRef(listLoanRepaymentsVars);
// Variables can be defined inline as well.
const ref = listLoanRepaymentsRef({ loanId: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listLoanRepaymentsRef(dataConnect, listLoanRepaymentsVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.loanRepayments);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.loanRepayments);
});
```

## ListMyTransactions
You can execute the `ListMyTransactions` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listMyTransactions(options?: ExecuteQueryOptions): QueryPromise<ListMyTransactionsData, undefined>;

interface ListMyTransactionsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListMyTransactionsData, undefined>;
}
export const listMyTransactionsRef: ListMyTransactionsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listMyTransactions(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListMyTransactionsData, undefined>;

interface ListMyTransactionsRef {
  ...
  (dc: DataConnect): QueryRef<ListMyTransactionsData, undefined>;
}
export const listMyTransactionsRef: ListMyTransactionsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listMyTransactionsRef:
```typescript
const name = listMyTransactionsRef.operationName;
console.log(name);
```

### Variables
The `ListMyTransactions` query has no variables.
### Return Type
Recall that executing the `ListMyTransactions` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListMyTransactionsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListMyTransactionsData {
  transactions: ({
    amount: number;
    type: string;
    date: TimestampString;
  })[];
}
```
### Using `ListMyTransactions`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listMyTransactions } from '@dataconnect/generated';


// Call the `listMyTransactions()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listMyTransactions();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listMyTransactions(dataConnect);

console.log(data.transactions);

// Or, you can use the `Promise` API.
listMyTransactions().then((response) => {
  const data = response.data;
  console.log(data.transactions);
});
```

### Using `ListMyTransactions`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listMyTransactionsRef } from '@dataconnect/generated';


// Call the `listMyTransactionsRef()` function to get a reference to the query.
const ref = listMyTransactionsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listMyTransactionsRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.transactions);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.transactions);
});
```

# Mutations

There are two ways to execute a Data Connect Mutation using the generated Web SDK:
- Using a Mutation Reference function, which returns a `MutationRef`
  - The `MutationRef` can be used as an argument to `executeMutation()`, which will execute the Mutation and return a `MutationPromise`
- Using an action shortcut function, which returns a `MutationPromise`
  - Calling the action shortcut function will execute the Mutation and return a `MutationPromise`

The following is true for both the action shortcut function and the `MutationRef` function:
- The `MutationPromise` returned will resolve to the result of the Mutation once it has finished executing
- If the Mutation accepts arguments, both the action shortcut function and the `MutationRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Mutation
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `example` connector's generated functions to execute each mutation. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-mutations).

## CreateMemberData
You can execute the `CreateMemberData` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createMemberData(vars: CreateMemberDataVariables): MutationPromise<CreateMemberDataData, CreateMemberDataVariables>;

interface CreateMemberDataRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateMemberDataVariables): MutationRef<CreateMemberDataData, CreateMemberDataVariables>;
}
export const createMemberDataRef: CreateMemberDataRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createMemberData(dc: DataConnect, vars: CreateMemberDataVariables): MutationPromise<CreateMemberDataData, CreateMemberDataVariables>;

interface CreateMemberDataRef {
  ...
  (dc: DataConnect, vars: CreateMemberDataVariables): MutationRef<CreateMemberDataData, CreateMemberDataVariables>;
}
export const createMemberDataRef: CreateMemberDataRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createMemberDataRef:
```typescript
const name = createMemberDataRef.operationName;
console.log(name);
```

### Variables
The `CreateMemberData` mutation requires an argument of type `CreateMemberDataVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateMemberDataVariables {
  fullName: string;
  email: string;
  phone: string;
}
```
### Return Type
Recall that executing the `CreateMemberData` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateMemberDataData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateMemberDataData {
  member_insert: Member_Key;
}
```
### Using `CreateMemberData`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createMemberData, CreateMemberDataVariables } from '@dataconnect/generated';

// The `CreateMemberData` mutation requires an argument of type `CreateMemberDataVariables`:
const createMemberDataVars: CreateMemberDataVariables = {
  fullName: ..., 
  email: ..., 
  phone: ..., 
};

// Call the `createMemberData()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createMemberData(createMemberDataVars);
// Variables can be defined inline as well.
const { data } = await createMemberData({ fullName: ..., email: ..., phone: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createMemberData(dataConnect, createMemberDataVars);

console.log(data.member_insert);

// Or, you can use the `Promise` API.
createMemberData(createMemberDataVars).then((response) => {
  const data = response.data;
  console.log(data.member_insert);
});
```

### Using `CreateMemberData`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createMemberDataRef, CreateMemberDataVariables } from '@dataconnect/generated';

// The `CreateMemberData` mutation requires an argument of type `CreateMemberDataVariables`:
const createMemberDataVars: CreateMemberDataVariables = {
  fullName: ..., 
  email: ..., 
  phone: ..., 
};

// Call the `createMemberDataRef()` function to get a reference to the mutation.
const ref = createMemberDataRef(createMemberDataVars);
// Variables can be defined inline as well.
const ref = createMemberDataRef({ fullName: ..., email: ..., phone: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createMemberDataRef(dataConnect, createMemberDataVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.member_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.member_insert);
});
```

## UpdateMemberProfile
You can execute the `UpdateMemberProfile` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateMemberProfile(vars: UpdateMemberProfileVariables): MutationPromise<UpdateMemberProfileData, UpdateMemberProfileVariables>;

interface UpdateMemberProfileRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateMemberProfileVariables): MutationRef<UpdateMemberProfileData, UpdateMemberProfileVariables>;
}
export const updateMemberProfileRef: UpdateMemberProfileRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateMemberProfile(dc: DataConnect, vars: UpdateMemberProfileVariables): MutationPromise<UpdateMemberProfileData, UpdateMemberProfileVariables>;

interface UpdateMemberProfileRef {
  ...
  (dc: DataConnect, vars: UpdateMemberProfileVariables): MutationRef<UpdateMemberProfileData, UpdateMemberProfileVariables>;
}
export const updateMemberProfileRef: UpdateMemberProfileRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateMemberProfileRef:
```typescript
const name = updateMemberProfileRef.operationName;
console.log(name);
```

### Variables
The `UpdateMemberProfile` mutation requires an argument of type `UpdateMemberProfileVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateMemberProfileVariables {
  fullName: string;
}
```
### Return Type
Recall that executing the `UpdateMemberProfile` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateMemberProfileData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateMemberProfileData {
  member_update?: Member_Key | null;
}
```
### Using `UpdateMemberProfile`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateMemberProfile, UpdateMemberProfileVariables } from '@dataconnect/generated';

// The `UpdateMemberProfile` mutation requires an argument of type `UpdateMemberProfileVariables`:
const updateMemberProfileVars: UpdateMemberProfileVariables = {
  fullName: ..., 
};

// Call the `updateMemberProfile()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateMemberProfile(updateMemberProfileVars);
// Variables can be defined inline as well.
const { data } = await updateMemberProfile({ fullName: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateMemberProfile(dataConnect, updateMemberProfileVars);

console.log(data.member_update);

// Or, you can use the `Promise` API.
updateMemberProfile(updateMemberProfileVars).then((response) => {
  const data = response.data;
  console.log(data.member_update);
});
```

### Using `UpdateMemberProfile`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateMemberProfileRef, UpdateMemberProfileVariables } from '@dataconnect/generated';

// The `UpdateMemberProfile` mutation requires an argument of type `UpdateMemberProfileVariables`:
const updateMemberProfileVars: UpdateMemberProfileVariables = {
  fullName: ..., 
};

// Call the `updateMemberProfileRef()` function to get a reference to the mutation.
const ref = updateMemberProfileRef(updateMemberProfileVars);
// Variables can be defined inline as well.
const ref = updateMemberProfileRef({ fullName: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateMemberProfileRef(dataConnect, updateMemberProfileVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.member_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.member_update);
});
```

## DeleteMember
You can execute the `DeleteMember` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteMember(): MutationPromise<DeleteMemberData, undefined>;

interface DeleteMemberRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<DeleteMemberData, undefined>;
}
export const deleteMemberRef: DeleteMemberRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteMember(dc: DataConnect): MutationPromise<DeleteMemberData, undefined>;

interface DeleteMemberRef {
  ...
  (dc: DataConnect): MutationRef<DeleteMemberData, undefined>;
}
export const deleteMemberRef: DeleteMemberRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteMemberRef:
```typescript
const name = deleteMemberRef.operationName;
console.log(name);
```

### Variables
The `DeleteMember` mutation has no variables.
### Return Type
Recall that executing the `DeleteMember` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteMemberData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteMemberData {
  member_delete?: Member_Key | null;
}
```
### Using `DeleteMember`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteMember } from '@dataconnect/generated';


// Call the `deleteMember()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteMember();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteMember(dataConnect);

console.log(data.member_delete);

// Or, you can use the `Promise` API.
deleteMember().then((response) => {
  const data = response.data;
  console.log(data.member_delete);
});
```

### Using `DeleteMember`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteMemberRef } from '@dataconnect/generated';


// Call the `deleteMemberRef()` function to get a reference to the mutation.
const ref = deleteMemberRef();

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteMemberRef(dataConnect);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.member_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.member_delete);
});
```

## CreateAccount
You can execute the `CreateAccount` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createAccount(vars: CreateAccountVariables): MutationPromise<CreateAccountData, CreateAccountVariables>;

interface CreateAccountRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateAccountVariables): MutationRef<CreateAccountData, CreateAccountVariables>;
}
export const createAccountRef: CreateAccountRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createAccount(dc: DataConnect, vars: CreateAccountVariables): MutationPromise<CreateAccountData, CreateAccountVariables>;

interface CreateAccountRef {
  ...
  (dc: DataConnect, vars: CreateAccountVariables): MutationRef<CreateAccountData, CreateAccountVariables>;
}
export const createAccountRef: CreateAccountRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createAccountRef:
```typescript
const name = createAccountRef.operationName;
console.log(name);
```

### Variables
The `CreateAccount` mutation requires an argument of type `CreateAccountVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateAccountVariables {
  totalSavings: number;
}
```
### Return Type
Recall that executing the `CreateAccount` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateAccountData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateAccountData {
  account_insert: Account_Key;
}
```
### Using `CreateAccount`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createAccount, CreateAccountVariables } from '@dataconnect/generated';

// The `CreateAccount` mutation requires an argument of type `CreateAccountVariables`:
const createAccountVars: CreateAccountVariables = {
  totalSavings: ..., 
};

// Call the `createAccount()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createAccount(createAccountVars);
// Variables can be defined inline as well.
const { data } = await createAccount({ totalSavings: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createAccount(dataConnect, createAccountVars);

console.log(data.account_insert);

// Or, you can use the `Promise` API.
createAccount(createAccountVars).then((response) => {
  const data = response.data;
  console.log(data.account_insert);
});
```

### Using `CreateAccount`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createAccountRef, CreateAccountVariables } from '@dataconnect/generated';

// The `CreateAccount` mutation requires an argument of type `CreateAccountVariables`:
const createAccountVars: CreateAccountVariables = {
  totalSavings: ..., 
};

// Call the `createAccountRef()` function to get a reference to the mutation.
const ref = createAccountRef(createAccountVars);
// Variables can be defined inline as well.
const ref = createAccountRef({ totalSavings: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createAccountRef(dataConnect, createAccountVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.account_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.account_insert);
});
```

## UpdateAccountSavings
You can execute the `UpdateAccountSavings` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateAccountSavings(vars: UpdateAccountSavingsVariables): MutationPromise<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;

interface UpdateAccountSavingsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateAccountSavingsVariables): MutationRef<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;
}
export const updateAccountSavingsRef: UpdateAccountSavingsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateAccountSavings(dc: DataConnect, vars: UpdateAccountSavingsVariables): MutationPromise<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;

interface UpdateAccountSavingsRef {
  ...
  (dc: DataConnect, vars: UpdateAccountSavingsVariables): MutationRef<UpdateAccountSavingsData, UpdateAccountSavingsVariables>;
}
export const updateAccountSavingsRef: UpdateAccountSavingsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateAccountSavingsRef:
```typescript
const name = updateAccountSavingsRef.operationName;
console.log(name);
```

### Variables
The `UpdateAccountSavings` mutation requires an argument of type `UpdateAccountSavingsVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateAccountSavingsVariables {
  id: UUIDString;
  totalSavings: number;
}
```
### Return Type
Recall that executing the `UpdateAccountSavings` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateAccountSavingsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateAccountSavingsData {
  account_update?: Account_Key | null;
}
```
### Using `UpdateAccountSavings`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateAccountSavings, UpdateAccountSavingsVariables } from '@dataconnect/generated';

// The `UpdateAccountSavings` mutation requires an argument of type `UpdateAccountSavingsVariables`:
const updateAccountSavingsVars: UpdateAccountSavingsVariables = {
  id: ..., 
  totalSavings: ..., 
};

// Call the `updateAccountSavings()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateAccountSavings(updateAccountSavingsVars);
// Variables can be defined inline as well.
const { data } = await updateAccountSavings({ id: ..., totalSavings: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateAccountSavings(dataConnect, updateAccountSavingsVars);

console.log(data.account_update);

// Or, you can use the `Promise` API.
updateAccountSavings(updateAccountSavingsVars).then((response) => {
  const data = response.data;
  console.log(data.account_update);
});
```

### Using `UpdateAccountSavings`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateAccountSavingsRef, UpdateAccountSavingsVariables } from '@dataconnect/generated';

// The `UpdateAccountSavings` mutation requires an argument of type `UpdateAccountSavingsVariables`:
const updateAccountSavingsVars: UpdateAccountSavingsVariables = {
  id: ..., 
  totalSavings: ..., 
};

// Call the `updateAccountSavingsRef()` function to get a reference to the mutation.
const ref = updateAccountSavingsRef(updateAccountSavingsVars);
// Variables can be defined inline as well.
const ref = updateAccountSavingsRef({ id: ..., totalSavings: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateAccountSavingsRef(dataConnect, updateAccountSavingsVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.account_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.account_update);
});
```

## DeleteAccount
You can execute the `DeleteAccount` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteAccount(vars: DeleteAccountVariables): MutationPromise<DeleteAccountData, DeleteAccountVariables>;

interface DeleteAccountRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteAccountVariables): MutationRef<DeleteAccountData, DeleteAccountVariables>;
}
export const deleteAccountRef: DeleteAccountRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteAccount(dc: DataConnect, vars: DeleteAccountVariables): MutationPromise<DeleteAccountData, DeleteAccountVariables>;

interface DeleteAccountRef {
  ...
  (dc: DataConnect, vars: DeleteAccountVariables): MutationRef<DeleteAccountData, DeleteAccountVariables>;
}
export const deleteAccountRef: DeleteAccountRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteAccountRef:
```typescript
const name = deleteAccountRef.operationName;
console.log(name);
```

### Variables
The `DeleteAccount` mutation requires an argument of type `DeleteAccountVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeleteAccountVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `DeleteAccount` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteAccountData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteAccountData {
  account_delete?: Account_Key | null;
}
```
### Using `DeleteAccount`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteAccount, DeleteAccountVariables } from '@dataconnect/generated';

// The `DeleteAccount` mutation requires an argument of type `DeleteAccountVariables`:
const deleteAccountVars: DeleteAccountVariables = {
  id: ..., 
};

// Call the `deleteAccount()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteAccount(deleteAccountVars);
// Variables can be defined inline as well.
const { data } = await deleteAccount({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteAccount(dataConnect, deleteAccountVars);

console.log(data.account_delete);

// Or, you can use the `Promise` API.
deleteAccount(deleteAccountVars).then((response) => {
  const data = response.data;
  console.log(data.account_delete);
});
```

### Using `DeleteAccount`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteAccountRef, DeleteAccountVariables } from '@dataconnect/generated';

// The `DeleteAccount` mutation requires an argument of type `DeleteAccountVariables`:
const deleteAccountVars: DeleteAccountVariables = {
  id: ..., 
};

// Call the `deleteAccountRef()` function to get a reference to the mutation.
const ref = deleteAccountRef(deleteAccountVars);
// Variables can be defined inline as well.
const ref = deleteAccountRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteAccountRef(dataConnect, deleteAccountVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.account_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.account_delete);
});
```

## CreateLoan
You can execute the `CreateLoan` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createLoan(vars: CreateLoanVariables): MutationPromise<CreateLoanData, CreateLoanVariables>;

interface CreateLoanRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateLoanVariables): MutationRef<CreateLoanData, CreateLoanVariables>;
}
export const createLoanRef: CreateLoanRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createLoan(dc: DataConnect, vars: CreateLoanVariables): MutationPromise<CreateLoanData, CreateLoanVariables>;

interface CreateLoanRef {
  ...
  (dc: DataConnect, vars: CreateLoanVariables): MutationRef<CreateLoanData, CreateLoanVariables>;
}
export const createLoanRef: CreateLoanRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createLoanRef:
```typescript
const name = createLoanRef.operationName;
console.log(name);
```

### Variables
The `CreateLoan` mutation requires an argument of type `CreateLoanVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateLoanVariables {
  principal: number;
  interest: number;
  dueDate: DateString;
}
```
### Return Type
Recall that executing the `CreateLoan` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateLoanData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateLoanData {
  loan_insert: Loan_Key;
}
```
### Using `CreateLoan`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createLoan, CreateLoanVariables } from '@dataconnect/generated';

// The `CreateLoan` mutation requires an argument of type `CreateLoanVariables`:
const createLoanVars: CreateLoanVariables = {
  principal: ..., 
  interest: ..., 
  dueDate: ..., 
};

// Call the `createLoan()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createLoan(createLoanVars);
// Variables can be defined inline as well.
const { data } = await createLoan({ principal: ..., interest: ..., dueDate: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createLoan(dataConnect, createLoanVars);

console.log(data.loan_insert);

// Or, you can use the `Promise` API.
createLoan(createLoanVars).then((response) => {
  const data = response.data;
  console.log(data.loan_insert);
});
```

### Using `CreateLoan`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createLoanRef, CreateLoanVariables } from '@dataconnect/generated';

// The `CreateLoan` mutation requires an argument of type `CreateLoanVariables`:
const createLoanVars: CreateLoanVariables = {
  principal: ..., 
  interest: ..., 
  dueDate: ..., 
};

// Call the `createLoanRef()` function to get a reference to the mutation.
const ref = createLoanRef(createLoanVars);
// Variables can be defined inline as well.
const ref = createLoanRef({ principal: ..., interest: ..., dueDate: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createLoanRef(dataConnect, createLoanVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.loan_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.loan_insert);
});
```

## UpdateLoanStatus
You can execute the `UpdateLoanStatus` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateLoanStatus(vars: UpdateLoanStatusVariables): MutationPromise<UpdateLoanStatusData, UpdateLoanStatusVariables>;

interface UpdateLoanStatusRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateLoanStatusVariables): MutationRef<UpdateLoanStatusData, UpdateLoanStatusVariables>;
}
export const updateLoanStatusRef: UpdateLoanStatusRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateLoanStatus(dc: DataConnect, vars: UpdateLoanStatusVariables): MutationPromise<UpdateLoanStatusData, UpdateLoanStatusVariables>;

interface UpdateLoanStatusRef {
  ...
  (dc: DataConnect, vars: UpdateLoanStatusVariables): MutationRef<UpdateLoanStatusData, UpdateLoanStatusVariables>;
}
export const updateLoanStatusRef: UpdateLoanStatusRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateLoanStatusRef:
```typescript
const name = updateLoanStatusRef.operationName;
console.log(name);
```

### Variables
The `UpdateLoanStatus` mutation requires an argument of type `UpdateLoanStatusVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateLoanStatusVariables {
  id: UUIDString;
  status: string;
}
```
### Return Type
Recall that executing the `UpdateLoanStatus` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateLoanStatusData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateLoanStatusData {
  loan_update?: Loan_Key | null;
}
```
### Using `UpdateLoanStatus`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateLoanStatus, UpdateLoanStatusVariables } from '@dataconnect/generated';

// The `UpdateLoanStatus` mutation requires an argument of type `UpdateLoanStatusVariables`:
const updateLoanStatusVars: UpdateLoanStatusVariables = {
  id: ..., 
  status: ..., 
};

// Call the `updateLoanStatus()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateLoanStatus(updateLoanStatusVars);
// Variables can be defined inline as well.
const { data } = await updateLoanStatus({ id: ..., status: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateLoanStatus(dataConnect, updateLoanStatusVars);

console.log(data.loan_update);

// Or, you can use the `Promise` API.
updateLoanStatus(updateLoanStatusVars).then((response) => {
  const data = response.data;
  console.log(data.loan_update);
});
```

### Using `UpdateLoanStatus`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateLoanStatusRef, UpdateLoanStatusVariables } from '@dataconnect/generated';

// The `UpdateLoanStatus` mutation requires an argument of type `UpdateLoanStatusVariables`:
const updateLoanStatusVars: UpdateLoanStatusVariables = {
  id: ..., 
  status: ..., 
};

// Call the `updateLoanStatusRef()` function to get a reference to the mutation.
const ref = updateLoanStatusRef(updateLoanStatusVars);
// Variables can be defined inline as well.
const ref = updateLoanStatusRef({ id: ..., status: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateLoanStatusRef(dataConnect, updateLoanStatusVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.loan_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.loan_update);
});
```

## DeleteLoan
You can execute the `DeleteLoan` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteLoan(vars: DeleteLoanVariables): MutationPromise<DeleteLoanData, DeleteLoanVariables>;

interface DeleteLoanRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteLoanVariables): MutationRef<DeleteLoanData, DeleteLoanVariables>;
}
export const deleteLoanRef: DeleteLoanRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteLoan(dc: DataConnect, vars: DeleteLoanVariables): MutationPromise<DeleteLoanData, DeleteLoanVariables>;

interface DeleteLoanRef {
  ...
  (dc: DataConnect, vars: DeleteLoanVariables): MutationRef<DeleteLoanData, DeleteLoanVariables>;
}
export const deleteLoanRef: DeleteLoanRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteLoanRef:
```typescript
const name = deleteLoanRef.operationName;
console.log(name);
```

### Variables
The `DeleteLoan` mutation requires an argument of type `DeleteLoanVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeleteLoanVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `DeleteLoan` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteLoanData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteLoanData {
  loan_delete?: Loan_Key | null;
}
```
### Using `DeleteLoan`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteLoan, DeleteLoanVariables } from '@dataconnect/generated';

// The `DeleteLoan` mutation requires an argument of type `DeleteLoanVariables`:
const deleteLoanVars: DeleteLoanVariables = {
  id: ..., 
};

// Call the `deleteLoan()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteLoan(deleteLoanVars);
// Variables can be defined inline as well.
const { data } = await deleteLoan({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteLoan(dataConnect, deleteLoanVars);

console.log(data.loan_delete);

// Or, you can use the `Promise` API.
deleteLoan(deleteLoanVars).then((response) => {
  const data = response.data;
  console.log(data.loan_delete);
});
```

### Using `DeleteLoan`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteLoanRef, DeleteLoanVariables } from '@dataconnect/generated';

// The `DeleteLoan` mutation requires an argument of type `DeleteLoanVariables`:
const deleteLoanVars: DeleteLoanVariables = {
  id: ..., 
};

// Call the `deleteLoanRef()` function to get a reference to the mutation.
const ref = deleteLoanRef(deleteLoanVars);
// Variables can be defined inline as well.
const ref = deleteLoanRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteLoanRef(dataConnect, deleteLoanVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.loan_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.loan_delete);
});
```

## AddRepayment
You can execute the `AddRepayment` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
addRepayment(vars: AddRepaymentVariables): MutationPromise<AddRepaymentData, AddRepaymentVariables>;

interface AddRepaymentRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: AddRepaymentVariables): MutationRef<AddRepaymentData, AddRepaymentVariables>;
}
export const addRepaymentRef: AddRepaymentRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
addRepayment(dc: DataConnect, vars: AddRepaymentVariables): MutationPromise<AddRepaymentData, AddRepaymentVariables>;

interface AddRepaymentRef {
  ...
  (dc: DataConnect, vars: AddRepaymentVariables): MutationRef<AddRepaymentData, AddRepaymentVariables>;
}
export const addRepaymentRef: AddRepaymentRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the addRepaymentRef:
```typescript
const name = addRepaymentRef.operationName;
console.log(name);
```

### Variables
The `AddRepayment` mutation requires an argument of type `AddRepaymentVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface AddRepaymentVariables {
  loanId: UUIDString;
  amount: number;
}
```
### Return Type
Recall that executing the `AddRepayment` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `AddRepaymentData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface AddRepaymentData {
  loanRepayment_insert: LoanRepayment_Key;
}
```
### Using `AddRepayment`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, addRepayment, AddRepaymentVariables } from '@dataconnect/generated';

// The `AddRepayment` mutation requires an argument of type `AddRepaymentVariables`:
const addRepaymentVars: AddRepaymentVariables = {
  loanId: ..., 
  amount: ..., 
};

// Call the `addRepayment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await addRepayment(addRepaymentVars);
// Variables can be defined inline as well.
const { data } = await addRepayment({ loanId: ..., amount: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await addRepayment(dataConnect, addRepaymentVars);

console.log(data.loanRepayment_insert);

// Or, you can use the `Promise` API.
addRepayment(addRepaymentVars).then((response) => {
  const data = response.data;
  console.log(data.loanRepayment_insert);
});
```

### Using `AddRepayment`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, addRepaymentRef, AddRepaymentVariables } from '@dataconnect/generated';

// The `AddRepayment` mutation requires an argument of type `AddRepaymentVariables`:
const addRepaymentVars: AddRepaymentVariables = {
  loanId: ..., 
  amount: ..., 
};

// Call the `addRepaymentRef()` function to get a reference to the mutation.
const ref = addRepaymentRef(addRepaymentVars);
// Variables can be defined inline as well.
const ref = addRepaymentRef({ loanId: ..., amount: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = addRepaymentRef(dataConnect, addRepaymentVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.loanRepayment_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.loanRepayment_insert);
});
```

## UpdateRepayment
You can execute the `UpdateRepayment` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateRepayment(vars: UpdateRepaymentVariables): MutationPromise<UpdateRepaymentData, UpdateRepaymentVariables>;

interface UpdateRepaymentRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateRepaymentVariables): MutationRef<UpdateRepaymentData, UpdateRepaymentVariables>;
}
export const updateRepaymentRef: UpdateRepaymentRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateRepayment(dc: DataConnect, vars: UpdateRepaymentVariables): MutationPromise<UpdateRepaymentData, UpdateRepaymentVariables>;

interface UpdateRepaymentRef {
  ...
  (dc: DataConnect, vars: UpdateRepaymentVariables): MutationRef<UpdateRepaymentData, UpdateRepaymentVariables>;
}
export const updateRepaymentRef: UpdateRepaymentRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateRepaymentRef:
```typescript
const name = updateRepaymentRef.operationName;
console.log(name);
```

### Variables
The `UpdateRepayment` mutation requires an argument of type `UpdateRepaymentVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateRepaymentVariables {
  id: UUIDString;
  amount: number;
}
```
### Return Type
Recall that executing the `UpdateRepayment` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateRepaymentData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateRepaymentData {
  loanRepayment_update?: LoanRepayment_Key | null;
}
```
### Using `UpdateRepayment`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateRepayment, UpdateRepaymentVariables } from '@dataconnect/generated';

// The `UpdateRepayment` mutation requires an argument of type `UpdateRepaymentVariables`:
const updateRepaymentVars: UpdateRepaymentVariables = {
  id: ..., 
  amount: ..., 
};

// Call the `updateRepayment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateRepayment(updateRepaymentVars);
// Variables can be defined inline as well.
const { data } = await updateRepayment({ id: ..., amount: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateRepayment(dataConnect, updateRepaymentVars);

console.log(data.loanRepayment_update);

// Or, you can use the `Promise` API.
updateRepayment(updateRepaymentVars).then((response) => {
  const data = response.data;
  console.log(data.loanRepayment_update);
});
```

### Using `UpdateRepayment`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateRepaymentRef, UpdateRepaymentVariables } from '@dataconnect/generated';

// The `UpdateRepayment` mutation requires an argument of type `UpdateRepaymentVariables`:
const updateRepaymentVars: UpdateRepaymentVariables = {
  id: ..., 
  amount: ..., 
};

// Call the `updateRepaymentRef()` function to get a reference to the mutation.
const ref = updateRepaymentRef(updateRepaymentVars);
// Variables can be defined inline as well.
const ref = updateRepaymentRef({ id: ..., amount: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateRepaymentRef(dataConnect, updateRepaymentVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.loanRepayment_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.loanRepayment_update);
});
```

## DeleteRepayment
You can execute the `DeleteRepayment` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteRepayment(vars: DeleteRepaymentVariables): MutationPromise<DeleteRepaymentData, DeleteRepaymentVariables>;

interface DeleteRepaymentRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteRepaymentVariables): MutationRef<DeleteRepaymentData, DeleteRepaymentVariables>;
}
export const deleteRepaymentRef: DeleteRepaymentRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteRepayment(dc: DataConnect, vars: DeleteRepaymentVariables): MutationPromise<DeleteRepaymentData, DeleteRepaymentVariables>;

interface DeleteRepaymentRef {
  ...
  (dc: DataConnect, vars: DeleteRepaymentVariables): MutationRef<DeleteRepaymentData, DeleteRepaymentVariables>;
}
export const deleteRepaymentRef: DeleteRepaymentRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteRepaymentRef:
```typescript
const name = deleteRepaymentRef.operationName;
console.log(name);
```

### Variables
The `DeleteRepayment` mutation requires an argument of type `DeleteRepaymentVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeleteRepaymentVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `DeleteRepayment` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteRepaymentData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteRepaymentData {
  loanRepayment_delete?: LoanRepayment_Key | null;
}
```
### Using `DeleteRepayment`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteRepayment, DeleteRepaymentVariables } from '@dataconnect/generated';

// The `DeleteRepayment` mutation requires an argument of type `DeleteRepaymentVariables`:
const deleteRepaymentVars: DeleteRepaymentVariables = {
  id: ..., 
};

// Call the `deleteRepayment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteRepayment(deleteRepaymentVars);
// Variables can be defined inline as well.
const { data } = await deleteRepayment({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteRepayment(dataConnect, deleteRepaymentVars);

console.log(data.loanRepayment_delete);

// Or, you can use the `Promise` API.
deleteRepayment(deleteRepaymentVars).then((response) => {
  const data = response.data;
  console.log(data.loanRepayment_delete);
});
```

### Using `DeleteRepayment`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteRepaymentRef, DeleteRepaymentVariables } from '@dataconnect/generated';

// The `DeleteRepayment` mutation requires an argument of type `DeleteRepaymentVariables`:
const deleteRepaymentVars: DeleteRepaymentVariables = {
  id: ..., 
};

// Call the `deleteRepaymentRef()` function to get a reference to the mutation.
const ref = deleteRepaymentRef(deleteRepaymentVars);
// Variables can be defined inline as well.
const ref = deleteRepaymentRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteRepaymentRef(dataConnect, deleteRepaymentVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.loanRepayment_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.loanRepayment_delete);
});
```

## RecordTransaction
You can execute the `RecordTransaction` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
recordTransaction(vars: RecordTransactionVariables): MutationPromise<RecordTransactionData, RecordTransactionVariables>;

interface RecordTransactionRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: RecordTransactionVariables): MutationRef<RecordTransactionData, RecordTransactionVariables>;
}
export const recordTransactionRef: RecordTransactionRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
recordTransaction(dc: DataConnect, vars: RecordTransactionVariables): MutationPromise<RecordTransactionData, RecordTransactionVariables>;

interface RecordTransactionRef {
  ...
  (dc: DataConnect, vars: RecordTransactionVariables): MutationRef<RecordTransactionData, RecordTransactionVariables>;
}
export const recordTransactionRef: RecordTransactionRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the recordTransactionRef:
```typescript
const name = recordTransactionRef.operationName;
console.log(name);
```

### Variables
The `RecordTransaction` mutation requires an argument of type `RecordTransactionVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface RecordTransactionVariables {
  amount: number;
  type: string;
}
```
### Return Type
Recall that executing the `RecordTransaction` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `RecordTransactionData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface RecordTransactionData {
  transaction_insert: Transaction_Key;
}
```
### Using `RecordTransaction`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, recordTransaction, RecordTransactionVariables } from '@dataconnect/generated';

// The `RecordTransaction` mutation requires an argument of type `RecordTransactionVariables`:
const recordTransactionVars: RecordTransactionVariables = {
  amount: ..., 
  type: ..., 
};

// Call the `recordTransaction()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await recordTransaction(recordTransactionVars);
// Variables can be defined inline as well.
const { data } = await recordTransaction({ amount: ..., type: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await recordTransaction(dataConnect, recordTransactionVars);

console.log(data.transaction_insert);

// Or, you can use the `Promise` API.
recordTransaction(recordTransactionVars).then((response) => {
  const data = response.data;
  console.log(data.transaction_insert);
});
```

### Using `RecordTransaction`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, recordTransactionRef, RecordTransactionVariables } from '@dataconnect/generated';

// The `RecordTransaction` mutation requires an argument of type `RecordTransactionVariables`:
const recordTransactionVars: RecordTransactionVariables = {
  amount: ..., 
  type: ..., 
};

// Call the `recordTransactionRef()` function to get a reference to the mutation.
const ref = recordTransactionRef(recordTransactionVars);
// Variables can be defined inline as well.
const ref = recordTransactionRef({ amount: ..., type: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = recordTransactionRef(dataConnect, recordTransactionVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.transaction_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.transaction_insert);
});
```

## UpdateTransactionNotes
You can execute the `UpdateTransactionNotes` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateTransactionNotes(vars: UpdateTransactionNotesVariables): MutationPromise<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;

interface UpdateTransactionNotesRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateTransactionNotesVariables): MutationRef<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;
}
export const updateTransactionNotesRef: UpdateTransactionNotesRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateTransactionNotes(dc: DataConnect, vars: UpdateTransactionNotesVariables): MutationPromise<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;

interface UpdateTransactionNotesRef {
  ...
  (dc: DataConnect, vars: UpdateTransactionNotesVariables): MutationRef<UpdateTransactionNotesData, UpdateTransactionNotesVariables>;
}
export const updateTransactionNotesRef: UpdateTransactionNotesRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateTransactionNotesRef:
```typescript
const name = updateTransactionNotesRef.operationName;
console.log(name);
```

### Variables
The `UpdateTransactionNotes` mutation requires an argument of type `UpdateTransactionNotesVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateTransactionNotesVariables {
  id: UUIDString;
  notes: string;
}
```
### Return Type
Recall that executing the `UpdateTransactionNotes` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateTransactionNotesData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateTransactionNotesData {
  transaction_update?: Transaction_Key | null;
}
```
### Using `UpdateTransactionNotes`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateTransactionNotes, UpdateTransactionNotesVariables } from '@dataconnect/generated';

// The `UpdateTransactionNotes` mutation requires an argument of type `UpdateTransactionNotesVariables`:
const updateTransactionNotesVars: UpdateTransactionNotesVariables = {
  id: ..., 
  notes: ..., 
};

// Call the `updateTransactionNotes()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateTransactionNotes(updateTransactionNotesVars);
// Variables can be defined inline as well.
const { data } = await updateTransactionNotes({ id: ..., notes: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateTransactionNotes(dataConnect, updateTransactionNotesVars);

console.log(data.transaction_update);

// Or, you can use the `Promise` API.
updateTransactionNotes(updateTransactionNotesVars).then((response) => {
  const data = response.data;
  console.log(data.transaction_update);
});
```

### Using `UpdateTransactionNotes`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateTransactionNotesRef, UpdateTransactionNotesVariables } from '@dataconnect/generated';

// The `UpdateTransactionNotes` mutation requires an argument of type `UpdateTransactionNotesVariables`:
const updateTransactionNotesVars: UpdateTransactionNotesVariables = {
  id: ..., 
  notes: ..., 
};

// Call the `updateTransactionNotesRef()` function to get a reference to the mutation.
const ref = updateTransactionNotesRef(updateTransactionNotesVars);
// Variables can be defined inline as well.
const ref = updateTransactionNotesRef({ id: ..., notes: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateTransactionNotesRef(dataConnect, updateTransactionNotesVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.transaction_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.transaction_update);
});
```

## DeleteTransaction
You can execute the `DeleteTransaction` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteTransaction(vars: DeleteTransactionVariables): MutationPromise<DeleteTransactionData, DeleteTransactionVariables>;

interface DeleteTransactionRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteTransactionVariables): MutationRef<DeleteTransactionData, DeleteTransactionVariables>;
}
export const deleteTransactionRef: DeleteTransactionRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteTransaction(dc: DataConnect, vars: DeleteTransactionVariables): MutationPromise<DeleteTransactionData, DeleteTransactionVariables>;

interface DeleteTransactionRef {
  ...
  (dc: DataConnect, vars: DeleteTransactionVariables): MutationRef<DeleteTransactionData, DeleteTransactionVariables>;
}
export const deleteTransactionRef: DeleteTransactionRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteTransactionRef:
```typescript
const name = deleteTransactionRef.operationName;
console.log(name);
```

### Variables
The `DeleteTransaction` mutation requires an argument of type `DeleteTransactionVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeleteTransactionVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `DeleteTransaction` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteTransactionData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteTransactionData {
  transaction_delete?: Transaction_Key | null;
}
```
### Using `DeleteTransaction`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteTransaction, DeleteTransactionVariables } from '@dataconnect/generated';

// The `DeleteTransaction` mutation requires an argument of type `DeleteTransactionVariables`:
const deleteTransactionVars: DeleteTransactionVariables = {
  id: ..., 
};

// Call the `deleteTransaction()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteTransaction(deleteTransactionVars);
// Variables can be defined inline as well.
const { data } = await deleteTransaction({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteTransaction(dataConnect, deleteTransactionVars);

console.log(data.transaction_delete);

// Or, you can use the `Promise` API.
deleteTransaction(deleteTransactionVars).then((response) => {
  const data = response.data;
  console.log(data.transaction_delete);
});
```

### Using `DeleteTransaction`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteTransactionRef, DeleteTransactionVariables } from '@dataconnect/generated';

// The `DeleteTransaction` mutation requires an argument of type `DeleteTransactionVariables`:
const deleteTransactionVars: DeleteTransactionVariables = {
  id: ..., 
};

// Call the `deleteTransactionRef()` function to get a reference to the mutation.
const ref = deleteTransactionRef(deleteTransactionVars);
// Variables can be defined inline as well.
const ref = deleteTransactionRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteTransactionRef(dataConnect, deleteTransactionVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.transaction_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.transaction_delete);
});
```

