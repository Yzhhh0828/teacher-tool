def test_imports_database_module_from_repo_root():
    from app.database import Base

    assert Base is not None
