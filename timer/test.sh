#!/usr/bin/env bash
# Test suite for timer with SQLite database

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMER="$SCRIPT_DIR/timer"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_PASSED=0

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
}

# Setup: create temp directory with mock SQLite database
setup() {
    TEST_DIR=$(mktemp -d)
    TEST_CWD="$TEST_DIR/project"
    mkdir -p "$TEST_CWD"
    
    # Create mock data directory structure
    DATA_DIR="$TEST_DIR/data"
    mkdir -p "$DATA_DIR"
    
    DB_PATH="$DATA_DIR/opencode.db"
    
    # Create SQLite database with opencode schema
    sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE project (
    id TEXT PRIMARY KEY,
    worktree TEXT NOT NULL,
    vcs TEXT,
    name TEXT,
    time_created INTEGER NOT NULL,
    time_updated INTEGER NOT NULL,
    sandboxes TEXT NOT NULL DEFAULT '[]'
);

CREATE TABLE session (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    parent_id TEXT,
    slug TEXT NOT NULL,
    directory TEXT NOT NULL,
    title TEXT NOT NULL,
    version TEXT NOT NULL,
    time_created INTEGER NOT NULL,
    time_updated INTEGER NOT NULL
);

CREATE TABLE message (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES session(id) ON DELETE CASCADE,
    time_created INTEGER NOT NULL,
    time_updated INTEGER NOT NULL,
    data TEXT NOT NULL
);

CREATE TABLE part (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL REFERENCES message(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL,
    time_created INTEGER NOT NULL,
    time_updated INTEGER NOT NULL,
    data TEXT NOT NULL
);
SQL
    
    export TEST_DIR TEST_CWD DATA_DIR DB_PATH
}

# Teardown: remove temp directory
teardown() {
    rm -rf "$TEST_DIR"
}

# Insert test data for a basic session
insert_basic_session() {
    local session_title="${1:-Test Session}"
    local now=1700000000000
    local created=$((now - 60000))
    local assistant_created=$((created + 1000))
    local assistant_completed=$((created + 11000))
    
    sqlite3 "$DB_PATH" "INSERT INTO project (id, worktree, time_created, time_updated, sandboxes) VALUES ('proj_001', '$TEST_CWD', $created, $now, '[]');"
    sqlite3 "$DB_PATH" "INSERT INTO session VALUES ('session_001', 'proj_001', NULL, 'test-slug', '$TEST_CWD', '$session_title', '1.2.0', $created, $now);"
    
    # User message with summary.title (counts as prompt)
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_001', 'session_001', $created, $now, '{\"role\":\"user\",\"time\":{\"created\":$created},\"summary\":{\"title\":\"User prompt\"}}');"
    
    # Assistant message with tokens and timing (10 seconds thinking time)
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_002', 'session_001', $assistant_created, $now, '{\"role\":\"assistant\",\"time\":{\"created\":$assistant_created,\"completed\":$assistant_completed},\"tokens\":{\"input\":1000,\"output\":500,\"reasoning\":100,\"cache\":{\"read\":800,\"write\":200}},\"parentID\":\"msg_001\"}');"
}

# Insert session with question tool (to test wait time subtraction)
insert_session_with_question() {
    local now=1700000000000
    local created=$((now - 120000))
    local assistant_created=$((created + 1000))
    local assistant_completed=$((created + 31000))  # 30s total
    local question_start=$((created + 5000))
    local question_end=$((created + 15000))  # 10s wait time
    
    sqlite3 "$DB_PATH" "INSERT INTO project (id, worktree, time_created, time_updated, sandboxes) VALUES ('proj_002', '$TEST_CWD', $created, $now, '[]');"
    sqlite3 "$DB_PATH" "INSERT INTO session VALUES ('session_002', 'proj_002', NULL, 'question-slug', '$TEST_CWD', 'Session with Question', '1.2.0', $created, $now);"
    
    # User message
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_003', 'session_002', $created, $now, '{\"role\":\"user\",\"time\":{\"created\":$created},\"summary\":{\"title\":\"User prompt\"}}');"
    
    # Assistant message: 30s total, but 10s was waiting for question answer
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_004', 'session_002', $assistant_created, $now, '{\"role\":\"assistant\",\"time\":{\"created\":$assistant_created,\"completed\":$assistant_completed},\"tokens\":{\"input\":2000,\"output\":1000,\"reasoning\":0,\"cache\":{\"read\":0,\"write\":0}},\"parentID\":\"msg_003\"}');"
    
    # Question tool part: 10s wait time
    sqlite3 "$DB_PATH" "INSERT INTO part VALUES ('part_001', 'msg_004', 'session_002', $question_start, $now, '{\"type\":\"tool\",\"tool\":\"question\",\"state\":{\"status\":\"completed\",\"time\":{\"start\":$question_start,\"end\":$question_end}}}');"
}

# Test: No sessions found
test_no_sessions() {
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    
    # Override HOME to use test data dir, run from test directory
    output=$(cd "$TEST_CWD" && HOME="$TEST_DIR" XDG_DATA_HOME="$DATA_DIR" "$TIMER" 2>&1) || true
    
    if [[ "$output" == *"No opencode session found"* ]]; then
        pass "no_sessions: shows error message"
    else
        fail "no_sessions" "Error message about no sessions" "$output"
    fi
    
    teardown
}

# Test: Basic session output format
test_basic_session() {
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    insert_basic_session "My Test Session"
    
    output=$(cd "$TEST_CWD" && HOME="$TEST_DIR" XDG_DATA_HOME="$DATA_DIR" "$TIMER" 2>&1)
    
    # Should contain time format HH:MM:SS
    if [[ "$output" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        pass "basic_session: time format correct"
    else
        fail "basic_session: time format" "HH:MM:SS format" "$output"
    fi
    
    TESTS_RUN=$((TESTS_RUN + 1))
    # Should contain prompt count
    if [[ "$output" =~ [0-9]+\ prompt ]]; then
        pass "basic_session: prompt count present"
    else
        fail "basic_session: prompt count" "N prompts" "$output"
    fi
    
    TESTS_RUN=$((TESTS_RUN + 1))
    # Should contain session title
    if [[ "$output" == *"My Test Session"* ]]; then
        pass "basic_session: title present"
    else
        fail "basic_session: title" "My Test Session" "$output"
    fi
    
    TESTS_RUN=$((TESTS_RUN + 1))
    # Should contain output and speed stats
    if [[ "$output" =~ output:.*tok/s ]]; then
        pass "basic_session: token stats present"
    else
        fail "basic_session: token stats" "output: X (Y tok/s)" "$output"
    fi
    
    teardown
}

# Test: Question wait time is subtracted
test_question_wait_time() {
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    insert_session_with_question
    
    output=$(cd "$TEST_CWD" && HOME="$TEST_DIR" XDG_DATA_HOME="$DATA_DIR" "$TIMER" 2>&1)
    
    # Total time was 30s, question wait was 10s, so thinking time should be 20s
    # Output should show 00:00:20 (or close to it given test timing)
    if [[ "$output" =~ 00:00:[12][0-9] ]]; then
        pass "question_wait_time: time correctly excludes question wait"
    else
        fail "question_wait_time" "~00:00:20 (30s - 10s question wait)" "$output"
    fi
    
    teardown
}

# Test: Verbose mode
test_verbose_mode() {
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    insert_basic_session "Verbose Test"
    
    output=$(cd "$TEST_CWD" && HOME="$TEST_DIR" XDG_DATA_HOME="$DATA_DIR" "$TIMER" -v 2>&1)
    
    # Verbose mode should show OUTPUT and CONTEXT sections
    if [[ "$output" == *"OUTPUT"* && "$output" == *"CONTEXT"* ]]; then
        pass "verbose_mode: shows detailed sections"
    else
        fail "verbose_mode" "OUTPUT and CONTEXT sections" "$output"
    fi
    
    TESTS_RUN=$((TESTS_RUN + 1))
    # Should show cache percentage
    if [[ "$output" == *"cached:"* && "$output" == *"%"* ]]; then
        pass "verbose_mode: shows cache percentage"
    else
        fail "verbose_mode: cache percentage" "cached: X%" "$output"
    fi
    
    teardown
}

# Test: Database not found
test_no_database() {
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Use a non-existent path
    output=$(HOME="/nonexistent" XDG_DATA_HOME="/nonexistent" "$TIMER" 2>&1) || true
    
    if [[ "$output" == *"Database not found"* ]] || [[ "$output" == *"No opencode session"* ]]; then
        pass "no_database: handles missing database"
    else
        fail "no_database" "Error about missing database" "$output"
    fi
}

# Test: Only shows most recent session when multiple exist
test_single_session_output() {
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    
    # Insert two sessions - older and newer
    local now=1700000000000
    local old_created=$((now - 120000))
    local new_created=$((now - 60000))
    
    sqlite3 "$DB_PATH" "INSERT INTO project (id, worktree, time_created, time_updated, sandboxes) VALUES ('proj_001', '$TEST_CWD', $old_created, $now, '[]');"
    
    # Old session
    sqlite3 "$DB_PATH" "INSERT INTO session VALUES ('session_old', 'proj_001', NULL, 'old', '$TEST_CWD', 'Old Session', '1.2.0', $old_created, $old_created);"
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_old_1', 'session_old', $old_created, $old_created, '{\"role\":\"user\",\"time\":{\"created\":$old_created},\"summary\":{\"title\":\"Old\"}}');"
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_old_2', 'session_old', $((old_created+1000)), $old_created, '{\"role\":\"assistant\",\"time\":{\"created\":$((old_created+1000)),\"completed\":$((old_created+5000))},\"tokens\":{\"input\":100,\"output\":50,\"reasoning\":0,\"cache\":{\"read\":0,\"write\":0}},\"parentID\":\"msg_old_1\"}');"
    
    # New session (more recent)
    sqlite3 "$DB_PATH" "INSERT INTO session VALUES ('session_new', 'proj_001', NULL, 'new', '$TEST_CWD', 'New Session', '1.2.0', $new_created, $now);"
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_new_1', 'session_new', $new_created, $now, '{\"role\":\"user\",\"time\":{\"created\":$new_created},\"summary\":{\"title\":\"New\"}}');"
    sqlite3 "$DB_PATH" "INSERT INTO message VALUES ('msg_new_2', 'session_new', $((new_created+1000)), $now, '{\"role\":\"assistant\",\"time\":{\"created\":$((new_created+1000)),\"completed\":$((new_created+10000))},\"tokens\":{\"input\":200,\"output\":100,\"reasoning\":0,\"cache\":{\"read\":0,\"write\":0}},\"parentID\":\"msg_new_1\"}');"
    
    output=$(cd "$TEST_CWD" && HOME="$TEST_DIR" XDG_DATA_HOME="$DATA_DIR" "$TIMER" 2>&1)
    
    # Should show only "New Session", not "Old Session"
    if [[ "$output" == *"New Session"* && "$output" != *"Old Session"* ]]; then
        pass "single_session: shows only most recent session"
    else
        fail "single_session" "Only 'New Session' shown" "$output"
    fi
    
    teardown
}

# Run all tests
main() {
    echo "Running timer tests..."
    echo ""
    
    test_no_database
    test_no_sessions
    test_basic_session
    test_question_wait_time
    test_verbose_mode
    test_single_session_output
    
    echo ""
    echo "================================"
    echo "Tests: $TESTS_RUN, Passed: $TESTS_PASSED, Failed: $((TESTS_RUN - TESTS_PASSED))"
    
    if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
