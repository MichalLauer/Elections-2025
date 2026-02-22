data {
  int<lower=0, upper=1> lik; // Should likelihood urn?

  int<lower=1> T; // How many days in total there were?
  int<lower=1> P; // How many poll were there?
  int<lower=1> K; // How many parties there are?
  int<lower=1> H; // How many houses there are?

  matrix[P, K] y; // Voteshare every poll-day that DO NOT have to sum to 1
  array[P] int<lower=1,upper=T> yt; // Poll-days
  row_vector<lower=1>[P] yn;        // Sample size for a given poll
  array[P] int<lower=1,upper=H> yh; // House for a given poll
}

transformed data {
  // Compute full matrix
  matrix[P, K + 1] y_full;
  y_full[1:P, 1:K] = y;
  y_full[1:P, K + 1] = 1.0 - y * rep_vector(1.0, K); // 1 - rowsum(y)

  // Convert initial state to CLR
  row_vector[K + 1] initial_state_clr = log(y_full[1]) - mean(log(y_full[1]));
}

parameters {
  // Parameters for mu
  row_vector<lower=0>[K + 1] mu_raw_sigma;
  matrix[T, K + 1] mu_raw_std;
  // Parameters for lambda
  row_vector<lower=0>[K + 1] lambda_raw_sigma;
  matrix[P, K + 1] lambda_raw_std;
  // Parameters for concentration
  row_vector<lower=0>[H] phi;
}

transformed parameters {
  // Non-centered latent parameter mu_raw
  matrix[T, K + 1] mu_raw;
  mu_raw[1] = initial_state_clr + mu_raw_sigma .* mu_raw_std[1];
  for (i in 2:T) {
    mu_raw[i] = mu_raw[i - 1] + mu_raw_sigma .* mu_raw_std[i];
  }

  // Non-centered latent parameter lambda_raw
  matrix[P, K + 1] lambda_raw;
  for (i in 1:P) {
    int poll_day = yt[i];
    lambda_raw[i] = mu_raw[poll_day] + lambda_raw_sigma .* lambda_raw_std[i];
  }

  // Unconstrained latent parameter lambda
  matrix[P, K + 1] lambda;
  for (i in 1:P) {
    lambda[i] = softmax(lambda_raw[i]')';
  }

  // Concentration of polls
  row_vector<lower=0>[P] concentration;
  for (i in 1:P) {
    int house = yh[i];
    concentration[i] = yn [i] * phi[house];
  }
}

model {
  // Standard, non-centered priors
  to_vector(mu_raw_std) ~ std_normal();
  to_vector(lambda_raw_std) ~ std_normal();

  // Non-centered priors for stdev
  to_vector(mu_raw_sigma) ~ exponential(1);
  to_vector(lambda_raw_sigma) ~ exponential(1);

  // Concentration
  phi ~ gamma(8, 10);
    
  // Likelihood is defined for every day with a poll
  if (lik == 1) {
    for (i in 1:P) {
      y_full[i] ~ dirichlet(lambda[i] * concentration[i]);
    }

  }
}

generated quantities {
  // Generate posteriors for true support mu
  matrix[T, K + 1] mu;
  for (i in 1:T) {
    mu[i] = softmax(mu_raw[i]')';
  }

  // Generate posterior predictive checks for polls
  matrix[P, K + 1] y_hat;
  for (i in 1:P) {
    int house = yh[i];
    real concentration_gen = yn[i] * phi[house];
    y_hat[i] = dirichlet_rng(lambda[i]' * concentration_gen)';
  }
}
