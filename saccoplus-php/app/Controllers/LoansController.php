<?php

namespace App\Controllers;

use App\Core\View;
use App\Core\Auth;
use App\Core\Csrf;
use App\Core\Validator;
use App\Models\Loan;
use App\Models\Member;
use App\Services\LoanService;
use Exception;

class LoansController
{
    private $loanService;
    
    public function __construct()
    {
        $this->loanService = new LoanService();
    }
    
    /**
     * List all loans
     */
    public function index()
    {
        Auth::requireLogin();
        
        $filters = [
            'status' => $_GET['status'] ?? '',
            'search' => $_GET['search'] ?? ''
        ];
        
        $loans = Loan::getAll($filters);
        
        View::render('loans/index', [
            'loans' => $loans,
            'filters' => $filters
        ]);
    }
    
    /**
     * Show loan application form
     */
    public function create()
    {
        Auth::requireRole(['admin', 'manager', 'accountant']);
        
        $memberId = $_GET['member_id'] ?? null;
        $member = null;
        
        if ($memberId) {
            $member = Member::getById($memberId);
        }
        
        View::render('loans/create', [
            'member' => $member,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Store new loan application
     */
    public function store()
    {
        Auth::requireRole(['admin', 'manager', 'accountant']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            // Validate
            $rules = [
                'member_id' => 'required|numeric',
                'loan_type' => 'required',
                'amount_requested' => 'required|numeric|min:10000',
                'amount_approved' => 'required|numeric|min:10000',
                'interest_rate' => 'required|numeric|min:0|max:50',
                'term_months' => 'required|numeric|min:1|max:60'
            ];
            
            $validator = new Validator($_POST, $rules);
            if (!$validator->validate()) {
                $_SESSION['errors'] = $validator->getErrors();
                $_SESSION['old'] = $_POST;
                redirect('/loans/create?member_id=' . ($_POST['member_id'] ?? ''));
                return;
            }
            
            // Apply for loan
            $loanId = $this->loanService->applyForLoan([
                'member_id' => $_POST['member_id'],
                'loan_type' => $_POST['loan_type'],
                'purpose' => $_POST['purpose'] ?? null,
                'amount_requested' => (int)$_POST['amount_requested'],
                'amount_approved' => (int)$_POST['amount_approved'],
                'interest_rate' => (float)$_POST['interest_rate'],
                'term_months' => (int)$_POST['term_months'],
                'repayment_frequency' => $_POST['repayment_frequency'] ?? 'monthly',
                'guarantor_1_id' => !empty($_POST['guarantor_1_id']) ? (int)$_POST['guarantor_1_id'] : null,
                'guarantor_1_amount' => !empty($_POST['guarantor_1_amount']) ? (int)$_POST['guarantor_1_amount'] : null,
                'guarantor_2_id' => !empty($_POST['guarantor_2_id']) ? (int)$_POST['guarantor_2_id'] : null,
                'guarantor_2_amount' => !empty($_POST['guarantor_2_amount']) ? (int)$_POST['guarantor_2_amount'] : null,
                'collateral_type' => $_POST['collateral_type'] ?? null,
                'collateral_value' => !empty($_POST['collateral_value']) ? (int)$_POST['collateral_value'] : null,
                'collateral_description' => $_POST['collateral_description'] ?? null,
            ], Auth::user()['id']);
            
            $_SESSION['success'] = "Loan application submitted successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            $_SESSION['old'] = $_POST;
            redirect('/loans/create?member_id=' . ($_POST['member_id'] ?? ''));
        }
    }
    
    /**
     * View loan details (with tabs: Summary / Schedule / Loan Card)
     */
    public function view()
    {
        Auth::requireLogin();
        
        $loanId = $_GET['id'] ?? null;
        if (!$loanId) {
            $_SESSION['error'] = "Loan ID required";
            redirect('/loans');
            return;
        }
        
        $loan = Loan::getById($loanId);
        if (!$loan) {
            $_SESSION['error'] = "Loan not found";
            redirect('/loans');
            return;
        }
        
        $tab = $_GET['tab'] ?? 'summary';
        
        // Get related data based on tab
        $schedule = [];
        $charges = [];
        $notes = [];
        $loanStatus = [];
        
        if ($tab === 'schedule') {
            $schedule = Loan::getSchedule($loanId);
        } elseif ($tab === 'card') {
            $charges = Loan::getCharges($loanId);
            $notes = Loan::getNotes($loanId);
        }
        
        // Always calculate status
        $loanStatus = $this->loanService->calculateLoanStatus($loan);
        
        View::render('loans/view', [
            'loan' => $loan,
            'tab' => $tab,
            'schedule' => $schedule,
            'charges' => $charges,
            'notes' => $notes,
            'loan_status' => $loanStatus,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Approve loan
     */
    public function approve()
    {
        Auth::requireRole(['admin', 'manager']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $_POST['loan_id'] ?? null;
            $approvedAmount = (int)($_POST['approved_amount'] ?? 0);
            $notes = $_POST['notes'] ?? '';
            
            if (!$loanId || !$approvedAmount) {
                throw new Exception("Missing required fields");
            }
            
            $this->loanService->approveLoan($loanId, $approvedAmount, $notes, Auth::user()['id']);
            
            $_SESSION['success'] = "Loan approved successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/view?id=' . ($_POST['loan_id'] ?? ''));
        }
    }
    
    /**
     * Reject loan
     */
    public function reject()
    {
        Auth::requireRole(['admin', 'manager']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $_POST['loan_id'] ?? null;
            $reason = $_POST['reason'] ?? '';
            
            if (!$loanId || !$reason) {
                throw new Exception("Missing required fields");
            }
            
            $this->loanService->rejectLoan($loanId, $reason, Auth::user()['id']);
            
            $_SESSION['success'] = "Loan rejected";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/view?id=' . ($_POST['loan_id'] ?? ''));
        }
    }
    
    /**
     * Disburse loan
     */
    public function disburse()
    {
        Auth::requireRole(['admin', 'manager', 'accountant']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $_POST['loan_id'] ?? null;
            $disbursementDate = $_POST['disbursement_date'] ?? date('Y-m-d');
            
            if (!$loanId) {
                throw new Exception("Loan ID required");
            }
            
            // Validate disbursement date (max 7 days backdate)
            $sevenDaysAgo = date('Y-m-d', strtotime('-7 days'));
            $today = date('Y-m-d');
            
            if ($disbursementDate < $sevenDaysAgo || $disbursementDate > $today) {
                throw new Exception("Disbursement date must be within the last 7 days");
            }
            
            $this->loanService->disburseLoan($loanId, $disbursementDate, Auth::user()['id']);
            
            $_SESSION['success'] = "Loan disbursed successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/view?id=' . ($_POST['loan_id'] ?? ''));
        }
    }
    
    /**
     * Show repayment form
     */
    public function repayForm()
    {
        Auth::requireRole(['admin', 'manager', 'teller', 'accountant']);
        
        $loanId = $_GET['loan_id'] ?? null;
        if (!$loanId) {
            $_SESSION['error'] = "Loan ID required";
            redirect('/loans');
            return;
        }
        
        $loan = Loan::getById($loanId);
        if (!$loan) {
            $_SESSION['error'] = "Loan not found";
            redirect('/loans');
            return;
        }
        
        $loanStatus = $this->loanService->calculateLoanStatus($loan);
        
        View::render('loans/repay', [
            'loan' => $loan,
            'loan_status' => $loanStatus,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Record loan repayment
     */
    public function repay()
    {
        Auth::requireRole(['admin', 'manager', 'teller', 'accountant']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $_POST['loan_id'] ?? null;
            $amount = (int)($_POST['amount'] ?? 0);
            $paymentDate = $_POST['payment_date'] ?? date('Y-m-d');
            $notes = $_POST['notes'] ?? '';
            
            if (!$loanId || !$amount) {
                throw new Exception("Missing required fields");
            }
            
            if ($amount < 1000) {
                throw new Exception("Minimum payment is UGX 1,000");
            }
            
            // Validate payment date (max 48 hours backdate)
            $twoDaysAgo = date('Y-m-d', strtotime('-48 hours'));
            $today = date('Y-m-d');
            
            if ($paymentDate < $twoDaysAgo || $paymentDate > $today) {
                throw new Exception("Payment date must be within the last 48 hours");
            }
            
            $this->loanService->recordRepayment($loanId, $amount, $paymentDate, $notes, Auth::user()['id']);
            
            $_SESSION['success'] = "Payment recorded successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            $_SESSION['old'] = $_POST;
            redirect('/loans/repay?loan_id=' . ($_POST['loan_id'] ?? ''));
        }
    }
    
    /**
     * Add manual charge
     */
    public function addCharge()
    {
        Auth::requireRole(['admin', 'manager']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $_POST['loan_id'] ?? null;
            $chargeType = $_POST['charge_type'] ?? null;
            $amount = (int)($_POST['amount'] ?? 0);
            $reason = $_POST['reason'] ?? '';
            
            if (!$loanId || !$chargeType || !$amount || !$reason) {
                throw new Exception("All fields are required");
            }
            
            if ($amount < 0) {
                throw new Exception("Amount must be positive");
            }
            
            $this->loanService->addCharge($loanId, $chargeType, $amount, $reason, Auth::user()['id']);
            
            $_SESSION['success'] = "Charge added successfully";
            redirect('/loans/view?id=' . $loanId . '&tab=card');
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/view?id=' . ($_POST['loan_id'] ?? '') . '&tab=card');
        }
    }
    
    /**
     * Correct loan data (admin only)
     */
    public function correctData()
    {
        Auth::requireRole(['admin']);
        
        $loanId = $_GET['loan_id'] ?? null;
        if (!$loanId) {
            $_SESSION['error'] = "Loan ID required";
            redirect('/loans');
            return;
        }
        
        $loan = Loan::getById($loanId);
        if (!$loan) {
            $_SESSION['error'] = "Loan not found";
            redirect('/loans');
            return;
        }
        
        View::render('loans/correct', [
            'loan' => $loan,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Store corrected loan data
     */
    public function storeCorrection()
    {
        Auth::requireRole(['admin']);
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $loanId = $_POST['loan_id'] ?? null;
            $reason = $_POST['reason'] ?? '';
            
            if (!$loanId || !$reason) {
                throw new Exception("Loan ID and reason are required");
            }
            
            $corrections = [];
            
            // Only include fields that were actually changed
            $fields = [
                'principal_balance', 'interest_balance', 'penalties_balance',
                'amount_approved', 'interest_rate', 'term_months',
                'opening_balance', 'opening_date', 'is_migrated'
            ];
            
            foreach ($fields as $field) {
                if (isset($_POST[$field]) && $_POST[$field] !== '') {
                    if (in_array($field, ['principal_balance', 'interest_balance', 'penalties_balance', 'amount_approved', 'opening_balance'])) {
                        $corrections[$field] = (int)$_POST[$field];
                    } elseif (in_array($field, ['interest_rate'])) {
                        $corrections[$field] = (float)$_POST[$field];
                    } elseif ($field === 'is_migrated') {
                        $corrections[$field] = $_POST[$field] === '1' ? 1 : 0;
                    } else {
                        $corrections[$field] = $_POST[$field];
                    }
                }
            }
            
            if (empty($corrections)) {
                throw new Exception("No changes were made");
            }
            
            $this->loanService->correctLoanData($loanId, $corrections, $reason, Auth::user()['id']);
            
            $_SESSION['success'] = "Loan data corrected successfully";
            redirect('/loans/view?id=' . $loanId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            redirect('/loans/correct?loan_id=' . ($_POST['loan_id'] ?? ''));
        }
    }
}
