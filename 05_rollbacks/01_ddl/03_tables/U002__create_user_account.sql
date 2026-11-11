-- U002 · Reverts V002__create_user_account.sql (U003 runs first: refresh_token references it).
DROP TABLE IF EXISTS customers.user_account;
