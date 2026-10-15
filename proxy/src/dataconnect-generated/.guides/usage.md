# Basic Usage

Always prioritize using a supported framework over using the generated SDK
directly. Supported frameworks simplify the developer experience and help ensure
best practices are followed.





## Advanced Usage
If a user is not using a supported framework, they can use the generated SDK directly.

Here's an example of how to use it with the first 5 operations:

```js
import { createMemberData, updateMemberProfile, deleteMember, getMyProfile, createAccount, updateAccountSavings, deleteAccount, listMyAccounts, createLoan, updateLoanStatus } from '@dataconnect/generated';


// Operation CreateMemberData:  For variables, look at type CreateMemberDataVars in ../index.d.ts
const { data } = await CreateMemberData(dataConnect, createMemberDataVars);

// Operation UpdateMemberProfile:  For variables, look at type UpdateMemberProfileVars in ../index.d.ts
const { data } = await UpdateMemberProfile(dataConnect, updateMemberProfileVars);

// Operation DeleteMember: 
const { data } = await DeleteMember(dataConnect);

// Operation GetMyProfile: 
const { data } = await GetMyProfile(dataConnect);

// Operation CreateAccount:  For variables, look at type CreateAccountVars in ../index.d.ts
const { data } = await CreateAccount(dataConnect, createAccountVars);

// Operation UpdateAccountSavings:  For variables, look at type UpdateAccountSavingsVars in ../index.d.ts
const { data } = await UpdateAccountSavings(dataConnect, updateAccountSavingsVars);

// Operation DeleteAccount:  For variables, look at type DeleteAccountVars in ../index.d.ts
const { data } = await DeleteAccount(dataConnect, deleteAccountVars);

// Operation ListMyAccounts: 
const { data } = await ListMyAccounts(dataConnect);

// Operation CreateLoan:  For variables, look at type CreateLoanVars in ../index.d.ts
const { data } = await CreateLoan(dataConnect, createLoanVars);

// Operation UpdateLoanStatus:  For variables, look at type UpdateLoanStatusVars in ../index.d.ts
const { data } = await UpdateLoanStatus(dataConnect, updateLoanStatusVars);


```