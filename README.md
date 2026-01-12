# Forecasting Elections in Multiparty Systems: A Bayesian Approach Combining Polls and Fundamentals

[https://doi.org/10.1017/pan.2018.49](https://doi.org/10.1017/pan.2018.49)

Používají dva modely:

## fundamental model

Predikuje výsledný vote-share pomocí Dirichlet rozdělení a kombinace tří prediktorů

- long-term preference strany (výsledky minulých voleb),
- short-term dynamika strany zhruba 150 dní před volbama (Intention to vote), a
- instituconální charakteristiku strany (zda má aktuálně premiéra).

Posteriorní rozdělení parametrů a posteriorní prediktivní rozdělení je použito do dynamického bayes modelu.

## dynamic bayesian model

Model používá backwards random walk od dne voleb ($T$) až na začátek sledovaného období. Díky tomu se dává apriorní
očekávání na den voleb, což jsou výsledky fundamentální modelu. Používá MultiNomial rozdělení s ALR transformací dat.
latentní složku rozkládá na vývoj strany a vliv výzkumné agentury. Taky jsou strany jako Motoristé, kteří nebyli předtím
a tím pádem by to byl pain predikovat.

## Problémy:

Paper má mnohem víc dat (polls), než je tady v česku. Taky jsem nenašel Intention to Vote, což vypadá jako nejdůležitější
prediktor fundamentálního modelu.

# Questions

- With what probability will party get into parlament?
- What is the most probable number of senators?
- What are the most probable coalitions?