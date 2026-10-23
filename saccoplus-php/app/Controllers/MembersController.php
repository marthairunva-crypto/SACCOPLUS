<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\{Auth, View};
use App\Models\Member;
use App\Services\MemberService;

class MembersController
{
    /**
     * List all members
     */
    public function index(): void
    {
        Auth::requireAuth();
        
        $saccoId = Auth::user()['sacco_id'];
        $page = (int) ($_GET['page'] ?? 1);
        $limit = 50;
        $offset = ($page - 1) * $limit;
        
        $members = Member::getAll($saccoId, $limit, $offset);
        $totalMembers = Member::count($saccoId);
        $totalPages = (int) ceil($totalMembers / $limit);
        
        View::render('members/index', [
            'members' => $members,
            'currentPage' => $page,
            'totalPages' => $totalPages,
            'totalMembers' => $totalMembers,
        ]);
    }

    /**
     * Member 360 view - comprehensive member profile
     */
    public function view(): void
    {
        Auth::requireAuth();
        
        $id = (int) ($_GET['id'] ?? 0);
        $saccoId = Auth::user()['sacco_id'];
        
        $member = MemberService::getMemberSummary($id, $saccoId);
        
        if (!$member) {
            http_response_code(404);
            View::render('404', ['message' => 'Member not found']);
            return;
        }
        
        View::render('members/view', ['member' => $member]);
    }

    /**
     * Search members (AJAX)
     */
    public function search(): void
    {
        Auth::requireAuth();
        header('Content-Type: application/json');
        
        $query = trim($_GET['q'] ?? '');
        $saccoId = Auth::user()['sacco_id'];
        
        if (strlen($query) < 2) {
            echo json_encode([]);
            return;
        }
        
        $results = Member::search($saccoId, $query);
        echo json_encode($results);
    }
}
